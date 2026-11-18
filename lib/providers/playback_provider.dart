import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'package:neiroha/data/services/synthesis/soloud_audio_sink.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

const voiceBankQuickTestPlaybackSource = 'voice_bank.quick_tts';
const phaseTtsPlaybackSource = 'phase_tts.preview';
const novelReaderPlaybackSource = 'novel_reader.playback';

String novelReaderPlaybackSourceFor(String projectId) =>
    '$novelReaderPlaybackSource:$projectId';

bool isNovelReaderPlaybackSource(String? sourceTag) =>
    sourceTag == novelReaderPlaybackSource ||
    sourceTag?.startsWith('$novelReaderPlaybackSource:') == true;

class PlaybackState {
  final String? audioPath;
  final String? title;
  final String? subtitle;
  final String? sourceTag;
  final bool isPlaying;
  final bool isStreaming;
  final bool isBuffering;
  final bool isPaused;
  final bool generationComplete;
  final Duration bufferedUntil;
  final String? error;
  bool get canSeek => !isStreaming && duration > Duration.zero;
  bool get hasMedia => audioPath != null || isStreaming;

  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.audioPath,
    this.title,
    this.subtitle,
    this.sourceTag,
    this.isPlaying = false,
    this.isStreaming = false,
    this.isBuffering = false,
    this.isPaused = false,
    this.generationComplete = false,
    this.bufferedUntil = Duration.zero,
    this.error,

    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    String? audioPath,
    String? title,
    String? subtitle,
    String? sourceTag,
    bool? isPlaying,
    bool? isStreaming,
    bool? isBuffering,
    bool? isPaused,
    bool? generationComplete,
    Duration? bufferedUntil,
    String? error,

    Duration? position,
    Duration? duration,
    bool clearMedia = false,
    bool clearSourceTag = false,
  }) {
    return PlaybackState(
      audioPath: clearMedia ? null : (audioPath ?? this.audioPath),
      title: clearMedia ? null : (title ?? this.title),
      subtitle: clearMedia ? null : (subtitle ?? this.subtitle),
      sourceTag: clearMedia || clearSourceTag
          ? null
          : (sourceTag ?? this.sourceTag),
      isPlaying: isPlaying ?? this.isPlaying,
      isStreaming: isStreaming ?? this.isStreaming,
      isBuffering: isBuffering ?? this.isBuffering,
      isPaused: isPaused ?? this.isPaused,
      generationComplete: generationComplete ?? this.generationComplete,
      bufferedUntil: bufferedUntil ?? this.bufferedUntil,
      error: error,

      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  static const _positionPublishInterval = Duration(milliseconds: 100);
  static const _mediaSessionProgressInterval = Duration(seconds: 1);

  late final AudioPlayer _player;
  StreamingAudioSink? _streamSink;
  TtsCancelToken? _streamCancellation;
  Timer? _streamPoll;
  int _streamRunId = 0;
  int _operationId = 0;

  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Completer<void>? _sequenceCancelCompleter;
  DateTime _lastPositionPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMediaSessionSyncedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _sequenceRunId = 0;

  @override
  PlaybackState build() {
    _player = ref.read(audioPlayerProvider);
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (state.isStreaming) return;
      _resetPositionPublishClock();
      state = state.copyWith(isPlaying: false, position: Duration.zero);
      unawaited(_syncNovelMediaSession(force: true));
    });
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!state.isStreaming) _publishPosition(pos);
    });
    _durationSub = _player.onDurationChanged.listen((dur) {
      if (state.isStreaming || state.duration == dur) return;
      state = state.copyWith(duration: dur);
      if (isNovelReaderPlaybackSource(state.sourceTag)) {
        unawaited(_syncNovelMediaSession(force: true));
      }
    });
    ref.onDispose(() {
      // Invalidate pending generation/drain callbacks before stopping the sink,
      // since stop() also completes its drained future.
      _streamRunId++;
      _operationId++;
      _cancelActiveSequence();
      _streamPoll?.cancel();
      _streamCancellation?.cancel();
      unawaited(_streamSink?.stop());
      _completeSub?.cancel();
      _positionSub?.cancel();
      _durationSub?.cancel();
    });
    return const PlaybackState();
  }

  Future<void> load(
    String audioPath,
    String title, {
    String? subtitle,
    String? sourceTag,
  }) async {
    _cancelActiveSequence();
    await _loadInternal(
      audioPath,
      title,
      subtitle: subtitle,
      sourceTag: sourceTag,
    );
  }

  Future<void> _loadInternal(
    String audioPath,
    String title, {
    String? subtitle,
    String? sourceTag,
  }) async {
    final operation = ++_operationId;
    await _stopStreaming();
    await _player.stop();
    if (operation != _operationId) return;
    _resetPositionPublishClock();
    state = const PlaybackState().copyWith(
      audioPath: audioPath,
      title: title,
      subtitle: subtitle,
      sourceTag: sourceTag,
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: true,
    );
    await _player.play(_sourceFor(audioPath));
    if (operation == _operationId) await _syncNovelMediaSession(force: true);
  }

  Future<void> togglePlay() async {
    final sink = _streamSink;
    if (sink != null) {
      final paused = !state.isPaused;
      await sink.pause(paused);
      if (_streamSink != sink) return;
      state = state.copyWith(isPaused: paused, isPlaying: !paused);
      await _syncNovelMediaSession(force: true);
      return;
    }
    if (state.audioPath == null) return;
    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      if (state.generationComplete && state.position == Duration.zero) {
        await _player.play(_sourceFor(state.audioPath!));
      } else {
        await _player.resume();
      }
      state = state.copyWith(isPlaying: true);
    }
    await _syncNovelMediaSession(force: true);
  }

  Source _sourceFor(String path) =>
      kIsWeb ? UrlSource(path) : DeviceFileSource(path);

  Future<void> stop() async {
    final operation = ++_operationId;
    final previousSourceTag = state.sourceTag;
    _cancelActiveSequence();
    await _stopStreaming();
    await _player.stop();
    if (operation != _operationId) return;
    _resetPositionPublishClock();
    state = const PlaybackState();
    if (isNovelReaderPlaybackSource(previousSourceTag)) {
      await ref.read(androidMediaSessionServiceProvider).stopNovelSession();
    }
  }

  /// Returns when generation/cache commit finishes. The speaker may still
  /// have buffered audio; state switches to the saved file only after drain.
  Future<SynthesisReceipt> playSynthesis({
    required Future<SynthesisReceipt> Function(StreamingAudioSink) generate,
    required TtsCancelToken cancellation,
    required String title,
    required String sourceTag,
    String? subtitle,
    StreamingAudioSink? sink,
  }) => _playStream<SynthesisReceipt>(
    generate: generate,
    audioUrl: (receipt) => receipt.audioPath,
    cancellation: cancellation,
    title: title,
    sourceTag: sourceTag,
    subtitle: subtitle,
    sink: sink,
  );

  Future<void> playSessionSynthesis({
    required Future<String> Function(StreamingAudioSink) generate,
    required TtsCancelToken cancellation,
    required String title,
    required String subtitle,
    required String sourceTag,
    required StreamingAudioSink sink,
  }) => _playStream<String>(
    generate: generate,
    audioUrl: (url) => url,
    cancellation: cancellation,
    title: title,
    sourceTag: sourceTag,
    subtitle: subtitle,
    sink: sink,
  );

  Future<T> _playStream<T>({
    required Future<T> Function(StreamingAudioSink) generate,
    required String Function(T) audioUrl,
    required TtsCancelToken cancellation,
    required String title,
    required String sourceTag,
    String? subtitle,
    StreamingAudioSink? sink,
  }) async {
    final operation = ++_operationId;
    _cancelActiveSequence();
    await _stopStreaming();
    await _player.stop();
    if (operation != _operationId) {
      cancellation.cancel();
      throw const TtsCancelledException();
    }
    cancellation.throwIfCancelled();
    final run = ++_streamRunId;
    final output = sink ?? SoloudAudioSink();
    _streamSink = output;
    _streamCancellation = cancellation;
    final removeCancel = cancellation.onCancel(() => unawaited(output.stop()));
    state = PlaybackState(
      title: title,
      subtitle: subtitle,
      sourceTag: sourceTag,
      isStreaming: true,
      isBuffering: true,
      isPlaying: true,
    );
    _streamPoll = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (run != _streamRunId) return;
      state = state.copyWith(
        position: output.position,
        bufferedUntil: output.bufferedUntil,
        isBuffering: output.isBuffering,
      );
      if (isNovelReaderPlaybackSource(state.sourceTag)) {
        unawaited(_syncNovelMediaSession());
      }
    });
    try {
      final receipt = await generate(output);
      if (run != _streamRunId) return receipt;
      final path = audioUrl(receipt);
      state = state.copyWith(audioPath: path, generationComplete: true);
      unawaited(
        output.drained.then((_) async {
          if (run != _streamRunId) return;
          _streamPoll?.cancel();
          final duration = output.bufferedUntil;
          state = PlaybackState(
            audioPath: path,
            title: title,
            subtitle: subtitle,
            sourceTag: sourceTag,
            duration: duration,
            generationComplete: true,
          );
          _streamSink = null;
          _streamCancellation = null;
          removeCancel();
          await output.stop();
        }),
      );
      return receipt;
    } catch (error) {
      if (run == _streamRunId) {
        await _stopStreaming();
        if (operation != _operationId) rethrow;
        state = error is TtsCancelledException
            ? const PlaybackState()
            : PlaybackState(
                title: title,
                sourceTag: sourceTag,
                error: '$error',
              );
      }
      rethrow;
    } finally {
      // Cancellation after generation must still stop buffered playback.
      if (run != _streamRunId) removeCancel();
    }
  }

  Future<void> _stopStreaming() async {
    _streamRunId++;
    _streamPoll?.cancel();
    final sink = _streamSink;
    _streamSink = null;
    final token = _streamCancellation;
    _streamCancellation = null;
    token?.cancel();
    await sink?.stop();
  }

  Future<void> stopIfSourceTag(String sourceTag) async {
    if (state.sourceTag != sourceTag) return;
    await stop();
  }

  Future<void> stopIfSourceTagPrefix(String sourceTagPrefix) async {
    if (state.sourceTag?.startsWith(sourceTagPrefix) != true) return;
    await stop();
  }

  Future<void> seek(Duration position) async {
    if (!state.canSeek) return;
    await _player.seek(position);
    _publishPosition(position, force: true);
  }

  /// Play a sequence of audio files sequentially (for Dialog TTS "play from here").
  Future<void> playSequenceFrom(
    List<({String audioPath, String title, String? subtitle})> items, {
    int startIndex = 0,
    String? sourceTag,
    Duration gap = Duration.zero,
  }) async {
    _cancelActiveSequence();
    final runId = _sequenceRunId;
    final cancelCompleter = Completer<void>();
    _sequenceCancelCompleter = cancelCompleter;
    for (int i = startIndex; i < items.length; i++) {
      if (_sequenceRunId != runId || cancelCompleter.isCompleted) break;
      final item = items[i];
      await _loadInternal(
        item.audioPath,
        item.title,
        subtitle: item.subtitle,
        sourceTag: sourceTag,
      );
      await Future.any([
        _player.onPlayerComplete.first,
        cancelCompleter.future,
      ]);
      // Same pause the merged export inserts between clips.
      if (gap > Duration.zero && i < items.length - 1) {
        await Future.any([Future<void>.delayed(gap), cancelCompleter.future]);
      }
    }
    if (_sequenceRunId == runId &&
        identical(_sequenceCancelCompleter, cancelCompleter)) {
      _sequenceCancelCompleter = null;
    }
  }

  void _cancelActiveSequence() {
    _sequenceRunId++;
    final completer = _sequenceCancelCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _sequenceCancelCompleter = null;
  }

  void _publishPosition(Duration position, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastPositionPublishedAt) < _positionPublishInterval) {
      return;
    }
    if (state.position == position) return;
    _lastPositionPublishedAt = now;
    state = state.copyWith(position: position);
    if (isNovelReaderPlaybackSource(state.sourceTag)) {
      unawaited(_syncNovelMediaSession(force: force));
    }
  }

  void _resetPositionPublishClock() {
    _lastPositionPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastMediaSessionSyncedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _syncNovelMediaSession({bool force = false}) async {
    final session = ref.read(androidMediaSessionServiceProvider);
    if (!isNovelReaderPlaybackSource(state.sourceTag) || !state.hasMedia) {
      await session.stopNovelSession();
      return;
    }
    final now = DateTime.now();
    if (!force &&
        now.difference(_lastMediaSessionSyncedAt) <
            _mediaSessionProgressInterval) {
      return;
    }
    _lastMediaSessionSyncedAt = now;
    await session.startOrUpdateNovelSession(
      title: state.title ?? 'Novel Reader',
      subtitle: state.subtitle,
      isPlaying: state.isPlaying,
      position: state.position,
      duration: state.duration,
    );
  }
}

/// Measure the duration of an audio file without disturbing global playback.
Future<double?> measureAudioDuration(String path) async {
  final probe = AudioPlayer();
  try {
    await probe.setSourceDeviceFile(path);
    final dur = await probe.getDuration();
    if (dur == null) return null;
    return dur.inMilliseconds / 1000.0;
  } catch (_) {
    return null;
  } finally {
    await probe.dispose();
  }
}

final playbackNotifierProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
