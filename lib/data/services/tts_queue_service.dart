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
  /// [beforeContinuation] accounts each further upstream request the chain
  /// makes (one per sentence) against the task's lease.
  Future<TtsAdapter> Function(
    TtsAdapter adapter,
    TtsRequest request, {
    Future<void> Function(TtsRequest request)? beforeContinuation,
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
  }) {
    if (cancelToken?.isCancelled ?? false) {
      return Future<T>.error(const TtsCancelledException());
    }
    final lane = queueLane(provider.id, capability);
    // The capability switch holds for every caller, also characters and
    // API requests bound to this connection directly, not just routing.
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
      run: task,
    );
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

      final wait = state.waitBeforeStart(limits, next.estimatedTokens);
      if (wait > Duration.zero) {
        state.timer = Timer(wait, () => _drain(providerId));
        return;
      }

      state.pending.removeFirst();
      state.recordStart(next.estimatedTokens);
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

class _ProviderQueueState {
  final Queue<_QueuedTtsTask<dynamic>> pending =
      Queue<_QueuedTtsTask<dynamic>>();
  final Set<_QueuedTtsTask<dynamic>> activeTasks = <_QueuedTtsTask<dynamic>>{};
  final List<_UsageStamp> _minuteUsage = <_UsageStamp>[];

  int _dayRequests = 0;
  int _dayTokens = 0;
  DateTime _dayStart = _today(DateTime.now());
  Timer? timer;

  Duration waitBeforeStart(QueueLimits provider, int tokens) {
    final now = DateTime.now();
    _prune(now);
    _resetDayIfNeeded(now);

    final waits = <Duration>[];
    final rpm = _positive(provider.requestsPerMinute);
    if (rpm != null && _minuteUsage.length >= rpm) {
      waits.add(_until(_minuteUsage.first.startedAt, now));
    }

    final tpm = _positive(provider.tokensPerMinute);
    if (tpm != null && tokens > tpm) {
      if (_minuteUsage.isNotEmpty) {
        waits.add(_until(_minuteUsage.first.startedAt, now));
      }
    } else if (tpm != null) {
      final currentTokens = _minuteUsage.fold<int>(
        0,
        (sum, stamp) => sum + stamp.tokens,
      );
      var projected = currentTokens + tokens;
      for (final stamp in _minuteUsage) {
        if (projected <= tpm) break;
        projected -= stamp.tokens;
        waits.add(_until(stamp.startedAt, now));
      }
    }

    final rpd = _positive(provider.requestsPerDay);
    if (rpd != null && _dayRequests >= rpd) {
      waits.add(_untilNextDay(now));
    }

    final tpd = _positive(provider.tokensPerDay);
    if (tpd != null &&
        ((tokens > tpd && _dayTokens > 0) ||
            (tokens <= tpd && _dayTokens + tokens > tpd))) {
      waits.add(_untilNextDay(now));
    }

    return waits.fold<Duration>(
      Duration.zero,
      (maxWait, wait) => wait > maxWait ? wait : maxWait,
    );
  }

  void recordStart(int tokens) {
    final now = DateTime.now();
    _prune(now);
    _resetDayIfNeeded(now);
    _minuteUsage.add(_UsageStamp(now, tokens));
    _dayRequests++;
    _dayTokens += tokens;
  }

  void _prune(DateTime now) {
    _minuteUsage.removeWhere(
      (stamp) =>
          now.difference(stamp.startedAt) >= TtsQueueService._minuteWindow,
    );
  }

  void _resetDayIfNeeded(DateTime now) {
    final today = _today(now);
    if (today == _dayStart) return;
    _dayStart = today;
    _dayRequests = 0;
    _dayTokens = 0;
  }

  Duration _until(DateTime startedAt, DateTime now) {
    final wait = startedAt.add(TtsQueueService._minuteWindow).difference(now);
    if (wait <= Duration.zero) return const Duration(milliseconds: 1);
    return wait + const Duration(milliseconds: 10);
  }

  Duration _untilNextDay(DateTime now) {
    return _today(now).add(const Duration(days: 1)).difference(now);
  }

  static int? _positive(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static DateTime _today(DateTime now) =>
      DateTime(now.year, now.month, now.day);
}

class _QueuedTtsTask<T> {
  _QueuedTtsTask({
    required this.id,
    required this.provider,
    required this.capability,
    required this.source,
    required this.label,
    required this.estimatedTokens,
    required this.run,
  }) : queuedAt = DateTime.now();

  final String id;
  final db.TtsProvider provider;
  final AiCapability capability;
  final String source;
  final String label;
  final int estimatedTokens;
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

class _UsageStamp {
  const _UsageStamp(this.startedAt, this.tokens);

  final DateTime startedAt;
  final int tokens;
}
