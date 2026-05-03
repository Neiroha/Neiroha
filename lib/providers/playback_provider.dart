import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

const voiceBankQuickTestPlaybackSource = 'voice_bank.quick_tts';
const phaseTtsPlaybackSource = 'phase_tts.preview';

class PlaybackState {
  final String? audioPath;
  final String? title;
  final String? subtitle;
  final String? sourceTag;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.audioPath,
    this.title,
    this.subtitle,
    this.sourceTag,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    String? audioPath,
    String? title,
    String? subtitle,
    String? sourceTag,
    bool? isPlaying,
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
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class PlaybackNotifier extends Notifier<PlaybackState> {
  late final AudioPlayer _player;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Completer<void>? _sequenceCancelCompleter;
  int _sequenceRunId = 0;

  @override
  PlaybackState build() {
    _player = ref.read(audioPlayerProvider);
    _completeSub = _player.onPlayerComplete.listen((_) {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    });
    _positionSub = _player.onPositionChanged.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _durationSub = _player.onDurationChanged.listen((dur) {
      state = state.copyWith(duration: dur);
    });
    ref.onDispose(() {
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
    await _player.stop();
    state = state.copyWith(
      audioPath: audioPath,
      title: title,
      subtitle: subtitle,
      sourceTag: sourceTag,
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: true,
    );
    await _player.play(DeviceFileSource(audioPath));
  }

  Future<void> togglePlay() async {
    if (state.audioPath == null) return;
    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _player.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> stop() async {
    _cancelActiveSequence();
    await _player.stop();
    state = const PlaybackState();
  }

  Future<void> stopIfSourceTag(String sourceTag) async {
    if (state.sourceTag != sourceTag) return;
    await stop();
  }

  Future<void> seek(Duration position) async {
    if (state.audioPath == null) return;
    await _player.seek(position);
    state = state.copyWith(position: position);
  }

  /// Play a sequence of audio files sequentially (for Dialog TTS "play from here").
  Future<void> playSequenceFrom(
    List<({String audioPath, String title, String? subtitle})> items, {
    int startIndex = 0,
    String? sourceTag,
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
