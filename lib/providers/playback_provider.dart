import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

class PlaybackState {
  final String? audioPath;
  final String? title;
  final String? subtitle;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.audioPath,
    this.title,
    this.subtitle,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    String? audioPath,
    String? title,
    String? subtitle,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool clearMedia = false,
  }) {
    return PlaybackState(
      audioPath: clearMedia ? null : (audioPath ?? this.audioPath),
      title: clearMedia ? null : (title ?? this.title),
      subtitle: clearMedia ? null : (subtitle ?? this.subtitle),
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
  }) async {
    await _player.stop();
    state = state.copyWith(
      audioPath: audioPath,
      title: title,
      subtitle: subtitle,
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
    await _player.stop();
    state = const PlaybackState();
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
  }) async {
    for (int i = startIndex; i < items.length; i++) {
      final item = items[i];
      await load(item.audioPath, item.title, subtitle: item.subtitle);
      await _player.onPlayerComplete.first;
    }
  }
}

final playbackNotifierProvider =
    NotifierProvider<PlaybackNotifier, PlaybackState>(PlaybackNotifier.new);
