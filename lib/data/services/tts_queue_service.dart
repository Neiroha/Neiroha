import 'synthesis/synthesis_service.dart';
import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
export 'package:neiroha/domain/synthesis/tts_cancellation.dart';
export 'package:neiroha/domain/ai/capability.dart' show AiCapability;
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/capability.dart';

import 'queue_limits.dart';

part 'tts_queue_state.dart';

/// Runs right before each request a processing chain sends upstream (one
/// per sentence, or the whole line), so it is counted when it is sent.
typedef ChainRequestHook =
    Future<void> Function(TtsRequest request, TtsCancelToken cancellation);

enum TtsQueueTaskStatus { queued, running, completed, failed }

class TtsQueueTaskSnapshot {
  const TtsQueueTaskSnapshot({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.source,
    required this.label,
    required this.status,
    required this.estimatedTokens,
    required this.queuedAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String source;
  final String label;
  final TtsQueueTaskStatus status;
  final int estimatedTokens;
  final DateTime queuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  bool get isUnfinished =>
      status == TtsQueueTaskStatus.queued ||
      status == TtsQueueTaskStatus.running;
}

class TtsQueueSnapshot {
  const TtsQueueSnapshot({
    this.running = const <TtsQueueTaskSnapshot>[],
    this.queued = const <TtsQueueTaskSnapshot>[],
    this.recent = const <TtsQueueTaskSnapshot>[],
  });

  final List<TtsQueueTaskSnapshot> running;
  final List<TtsQueueTaskSnapshot> queued;
  final List<TtsQueueTaskSnapshot> recent;

  int get runningCount => running.length;
  int get queuedCount => queued.length;
  int get unfinishedCount => running.length + queued.length;
  bool get hasUnfinished => unfinishedCount > 0;
}

/// Process-wide scheduler for all TTS synthesis requests.
///
/// The limits are intentionally owned by the provider instead of individual
/// screens. Quick TTS, Phase TTS, Novel Reader, Video Dub and the local API
/// server can all submit work here and receive the same concurrency / rate
/// behavior.
class TtsQueueService {
  TtsQueueService._();

  static final TtsQueueService instance = TtsQueueService._();

  /// Wraps a character's adapter in its processing chain; installed by the
  /// app at startup. Requests without a voice asset id pass through.
  /// [beforeRequest] accounts each upstream request the chain makes (one
  /// per sentence) against the task's lease.
  Future<TtsAdapter> Function(
    TtsAdapter adapter,
    TtsRequest request, {
    ChainRequestHook? beforeRequest,
  })?
  voiceChains;

  static const Duration _minuteWindow = Duration(minutes: 1);

  final Map<String, _ProviderQueueState> _states = {};
  Map<String, db.ConnectionCapability> _laneRows = const {};

  /// Per-capability limits (`connection_capabilities`); lanes without a row
  /// use the connection's own limits.
  void setCapabilityLimits(Iterable<db.ConnectionCapability> rows) {
    _laneRows = {for (final r in rows) _laneOf(r): r};
    _states.keys.toList().forEach(_drain);
  }

  static String _laneOf(db.ConnectionCapability r) => queueLane(
    r.connectionId,
    AiCapability.values.asNameMap()[r.capability] ?? AiCapability.tts,
  );

  QueueLimits _limits(db.TtsProvider p, AiCapability cap) =>
      QueueLimits.of(p, _laneRows[queueLane(p.id, cap)]);
  final StreamController<TtsQueueSnapshot> _snapshotController =
      StreamController<TtsQueueSnapshot>.broadcast();
  final List<TtsQueueTaskSnapshot> _recentFinished = <TtsQueueTaskSnapshot>[];
  int _nextTaskId = 0;

  TtsQueueSnapshot get snapshot {
    final running = <TtsQueueTaskSnapshot>[];
    final queued = <TtsQueueTaskSnapshot>[];

    for (final state in _states.values) {
      running.addAll(state.activeTasks.map((task) => task.toSnapshot()));
      queued.addAll(state.pending.map((task) => task.toSnapshot()));
    }

    running.sort(
      (a, b) =>
          (a.startedAt ?? a.queuedAt).compareTo(b.startedAt ?? b.queuedAt),
    );
    queued.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    return TtsQueueSnapshot(
      running: List.unmodifiable(running),
      queued: List.unmodifiable(queued),
      recent: List.unmodifiable(_recentFinished),
    );
  }

  Stream<TtsQueueSnapshot> watchSnapshots() async* {
    yield snapshot;
    yield* _snapshotController.stream;
  }

  Future<TtsResult> synthesize({
    required db.TtsProvider provider,
    required TtsRequest request,
    String? modelName,
    String source = 'TTS',
    String? label,
    TtsCancelToken? cancelToken,
  }) {
    return SynthesisService(this).collect(
      provider: provider,
      request: request,
      modelName: modelName,
      source: source,
      label: label ?? _labelForRequest(request),
      cancellation: cancelToken,
    );
  }

  Future<T> enqueue<T>({
    required db.TtsProvider provider,
    required Future<T> Function() task,
    int estimatedTokens = 1,
    String source = 'TTS',
    String label = 'TTS request',
    TtsCancelToken? cancelToken,
    bool interactive = false,
    AiCapability capability = AiCapability.tts,
    FutureOr<bool> accountsUsage = true,
  }) {
    if (cancelToken?.isCancelled ?? false) {
      return Future<T>.error(const TtsCancelledException());
    }
    final lane = queueLane(provider.id, capability);
    // The switch binds every caller, not just routing.
    if (_laneRows[lane]?.enabled == false) {
      return Future<T>.error(
        AiProviderException(
          '${capability.name.toUpperCase()} is turned off for '
          '"${provider.name}" in its settings.',
        ),
      );
    }
    final state = _states.putIfAbsent(lane, () => _ProviderQueueState());
    final queuedTask = _QueuedTtsTask<T>(
      id: '${++_nextTaskId}',
      provider: provider,
      capability: capability,
      source: source,
      label: label,
      estimatedTokens: math.max(1, estimatedTokens),
      accountsUsage: accountsUsage is bool ? accountsUsage : null,
      run: task,
    );
    // Decided shortly (whether a chain applies): the task keeps its place
    // and the lane waits for the answer; an error accounts as usual.
    if (accountsUsage is Future<bool>) {
      accountsUsage
          .then(
            (v) => queuedTask.accountsUsage = v,
            onError: (_) => queuedTask.accountsUsage = true,
          )
          .whenComplete(() => _drain(lane));
    }
    if (interactive) {
      state.pending.addFirst(queuedTask);
    } else {
      state.pending.add(queuedTask);
    }
    final removeCancelListener = cancelToken?.onCancel(() {
      if (!state.pending.remove(queuedTask)) return;
      queuedTask.completer.completeError(const TtsCancelledException());
      _emitSnapshot();
      _drain(lane);
    });
    _emitSnapshot();
    _drain(lane);
    return queuedTask.completer.future.whenComplete(() {
      removeCancelListener?.call();
    });
  }

  /// A multi-utterance session keeps its concurrency lease, but every further
  /// upstream request must still consume the provider's RPM/TPM/day budget.
  Future<void> accountContinuation(
    db.TtsProvider provider,
    TtsRequest request,
    TtsCancelToken cancellation,
  ) async {
    final state = _states[provider.id];
    if (state == null || state.activeTasks.isEmpty) {
      throw StateError('A continuation requires an active synthesis lease.');
    }
    final cancelled = Completer<void>();
    final remove = cancellation.onCancel(() => cancelled.complete());
    try {
      while (true) {
        cancellation.throwIfCancelled();
        final tokens = estimateTokens(request);
        final wait = state.waitBeforeStart(
          _limits(provider, AiCapability.tts),
          tokens,
        );
        if (wait <= Duration.zero) {
          state.recordStart(tokens);
          return;
        }
        final delay = Completer<void>();
        final timer = Timer(wait, delay.complete);
        try {
          await Future.any([delay.future, cancelled.future]);
        } finally {
          timer.cancel();
        }
      }
    } finally {
      remove();
    }
  }

  int estimateTokens(TtsRequest request) {
    final text = [
      request.audioTagPrefix,
      request.text,
      request.voiceInstruction,
      request.promptText,
    ].whereType<String>().join('\n');
    if (text.trim().isEmpty) return 1;

    var ascii = 0;
    for (final unit in text.codeUnits) {
      if (unit <= 0x7f) ascii++;
    }
    final nonAscii = text.length - ascii;
    return math.max(1, (ascii / 4 + nonAscii / 1.6).ceil());
  }

  String _labelForRequest(TtsRequest request) {
    final text = request.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return 'TTS request';
    if (text.length <= 72) return text;
    return '${text.substring(0, 72)}...';
  }

  void _drain(String providerId) {
    final state = _states[providerId];
    if (state == null) return;
    state.timer?.cancel();
    state.timer = null;

    while (state.pending.isNotEmpty) {
      final next = state.pending.first;
      final limits = _limits(next.provider, next.capability);
      if (state.activeTasks.length >= limits.maxConcurrency) return;

      // A task that accounts its own requests as it sends them (a chain)
      // only takes a concurrency slot here.
      final accounts = next.accountsUsage;
      if (accounts == null) return; // drained again once decided
      final wait = accounts
          ? state.waitBeforeStart(limits, next.estimatedTokens)
          : Duration.zero;
      if (wait > Duration.zero) {
        state.timer = Timer(wait, () => _drain(providerId));
        return;
      }

      state.pending.removeFirst();
      if (accounts) state.recordStart(next.estimatedTokens);
      next.markRunning();
      state.activeTasks.add(next);
      _emitSnapshot();
      unawaited(_run(providerId, state, next));
    }
  }

  Future<void> _run(
    String providerId,
    _ProviderQueueState state,
    _QueuedTtsTask<dynamic> task,
  ) async {
    try {
      final result = await task.run();
      task.markCompleted();
      if (!task.completer.isCompleted) task.completer.complete(result);
    } catch (error, stackTrace) {
      task.markFailed(error);
      if (!task.completer.isCompleted) {
        task.completer.completeError(error, stackTrace);
      }
    } finally {
      state.activeTasks.remove(task);
      _addRecent(task.toSnapshot());
      _emitSnapshot();
      _drain(providerId);
    }
  }

  void _addRecent(TtsQueueTaskSnapshot task) {
    _recentFinished.insert(0, task);
    if (_recentFinished.length > 50) {
      _recentFinished.removeRange(50, _recentFinished.length);
    }
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }
}

class _QueuedTtsTask<T> {
  _QueuedTtsTask({
    required this.id,
    required this.provider,
    required this.capability,
    required this.source,
    required this.label,
    required this.estimatedTokens,
    required this.accountsUsage,
    required this.run,
  }) : queuedAt = DateTime.now();

  final String id;
  final db.TtsProvider provider;
  final AiCapability capability;
  final String source;
  final String label;
  final int estimatedTokens;

  /// False when the task counts each upstream request itself; null until
  /// that is known.
  bool? accountsUsage;
  final Future<T> Function() run;
  final DateTime queuedAt;
  final Completer<T> completer = Completer<T>();
  DateTime? startedAt;
  DateTime? completedAt;
  String? errorMessage;
  TtsQueueTaskStatus status = TtsQueueTaskStatus.queued;

  void markRunning() {
    status = TtsQueueTaskStatus.running;
    startedAt = DateTime.now();
  }

  void markCompleted() {
    status = TtsQueueTaskStatus.completed;
    completedAt = DateTime.now();
  }

  void markFailed(Object error) {
    status = TtsQueueTaskStatus.failed;
    completedAt = DateTime.now();
    errorMessage = error.toString();
  }

  TtsQueueTaskSnapshot toSnapshot() {
    return TtsQueueTaskSnapshot(
      id: id,
      providerId: provider.id,
      providerName: provider.name,
      source: source,
      label: label,
      status: status,
      estimatedTokens: estimatedTokens,
      queuedAt: queuedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      errorMessage: errorMessage,
    );
  }
}
