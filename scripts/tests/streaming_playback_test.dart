import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/media_session_service.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

class _Player extends Fake implements AudioPlayer {
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Future<void> stop() async {}
}

class _Sink extends Fake implements StreamingAudioSink {
  final done = Completer<void>();
  bool stopped = false;
  bool paused = false;
  @override
  Future<void> get drained => done.future;
  @override
  Future<void> stop() async {
    stopped = true;
    if (!done.isCompleted) done.complete();
  }

  @override
  Future<void> pause(bool value) async => paused = value;
  @override
  Duration get position => const Duration(milliseconds: 100);
  @override
  Duration get bufferedUntil => const Duration(seconds: 1);
  @override
  bool get isBuffering => false;
}

SynthesisReceipt _receipt(String name) => SynthesisReceipt(
  audioPath: name,
  format: const TtsAudioFormat(AudioEncoding.wav),
  elapsed: Duration.zero,
  firstAudio: Duration.zero,
  completion: const TtsSynthesisCompleted(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  setUp(
    () => container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWithValue(_Player()),
        androidMediaSessionServiceProvider.overrideWith((ref) {
          final session = MediaSessionService(supported: false);
          ref.onDispose(session.dispose);
          return session;
        }),
      ],
    ),
  );
  tearDown(() => container.dispose());

  test('generation EOF retains streaming state until speaker drain', () async {
    final notifier = container.read(playbackNotifierProvider.notifier);
    final sink = _Sink();
    final token = TtsCancelToken();
    await notifier.playSynthesis(
      generate: (_) async => _receipt('result.wav'),
      cancellation: token,
      title: 'text',
      sourceTag: 'test',
      sink: sink,
    );
    var state = container.read(playbackNotifierProvider);
    expect(state.generationComplete, isTrue);
    expect(state.isStreaming, isTrue);
    expect(state.canSeek, isFalse);
    await notifier.togglePlay();
    expect(sink.paused, isTrue);
    sink.done.complete();
    await pumpEventQueue();
    state = container.read(playbackNotifierProvider);
    expect(state.isStreaming, isFalse);
    expect(state.isPlaying, isFalse);
    expect(state.audioPath, 'result.wav');
    expect(sink.stopped, isTrue);
  });

  test(
    'disposing buffered playback cancels without updating disposed state',
    () async {
      final notifier = container.read(playbackNotifierProvider.notifier);
      final sink = _Sink();
      final token = TtsCancelToken();
      await notifier.playSynthesis(
        generate: (_) async => _receipt('result.wav'),
        cancellation: token,
        title: 'text',
        sourceTag: 'test',
        sink: sink,
      );
      container.dispose();
      await pumpEventQueue();
      expect(token.isCancelled, isTrue);
      expect(sink.stopped, isTrue);
    },
  );

  test(
    'late generation completion after disposal cannot publish playback',
    () async {
      final notifier = container.read(playbackNotifierProvider.notifier);
      final sink = _Sink();
      final token = TtsCancelToken();
      final generation = Completer<SynthesisReceipt>();
      final playback = notifier.playSynthesis(
        generate: (_) => generation.future,
        cancellation: token,
        title: 'text',
        sourceTag: 'test',
        sink: sink,
      );
      await pumpEventQueue();
      container.dispose();
      generation.complete(_receipt('late.wav'));
      expect((await playback).audioPath, 'late.wav');
      await pumpEventQueue();
      expect(token.isCancelled, isTrue);
      expect(sink.stopped, isTrue);
    },
  );

  test(
    'stop cancels generation and obsolete completion cannot replace new playback',
    () async {
      final notifier = container.read(playbackNotifierProvider.notifier);
      final sink = _Sink();
      final token = TtsCancelToken();
      final gate = Completer<SynthesisReceipt>();
      final old = notifier.playSynthesis(
        generate: (_) => gate.future,
        cancellation: token,
        title: 'old',
        sourceTag: 'old',
        sink: sink,
      );
      await pumpEventQueue();
      await notifier.stop();
      expect(token.isCancelled, isTrue);
      expect(sink.stopped, isTrue);
      final nextSink = _Sink();
      await notifier.playSynthesis(
        generate: (_) async => _receipt('new.wav'),
        cancellation: TtsCancelToken(),
        title: 'new',
        sourceTag: 'new',
        sink: nextSink,
      );
      gate.complete(_receipt('old.wav'));
      await old;
      expect(container.read(playbackNotifierProvider).audioPath, 'new.wav');
      expect(container.read(playbackNotifierProvider).sourceTag, 'new');
      await notifier.stop();
    },
  );
}
