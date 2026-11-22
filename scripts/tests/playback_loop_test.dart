import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/media_session_service.dart';
import 'package:neiroha/presentation/actions/audio_download.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_loop.dart';
import 'package:neiroha/providers/playback_provider.dart';

class _Player extends Fake implements AudioPlayer {
  final complete = StreamController<void>.broadcast();
  final played = <String>[];

  @override
  Stream<void> get onPlayerComplete => complete.stream;
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Future<void> stop() async {}
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as DeviceFileSource).path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Player player;
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    player = _Player();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWithValue(player),
        databaseProvider.overrideWithValue(database),
        androidMediaSessionServiceProvider.overrideWith((ref) {
          final session = MediaSessionService(supported: false);
          ref.onDispose(session.dispose);
          return session;
        }),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await player.complete.close();
    await database.close();
  });

  Future<void> finishClip() async {
    player.complete.add(null);
    await pumpEventQueue();
  }

  test('single clips stop at the end while loop is off', () async {
    final notifier = container.read(playbackNotifierProvider.notifier);
    await notifier.load('a.wav', 'A', sourceTag: 'test');
    await finishClip();
    expect(player.played, ['a.wav']);
    expect(container.read(playbackNotifierProvider).isPlaying, isFalse);
  });

  test('loop replays the finished clip and persists the choice', () async {
    await container.read(playbackLoopProvider.notifier).set(true);
    final notifier = container.read(playbackNotifierProvider.notifier);
    await notifier.load('a.wav', 'A', sourceTag: 'test');
    await finishClip();
    await finishClip();
    expect(player.played, ['a.wav', 'a.wav', 'a.wav']);
    final state = container.read(playbackNotifierProvider);
    expect(state.isPlaying, isTrue);
    expect(state.position, Duration.zero);
    expect(await database.getSetting(PlaybackLoopNotifier.settingKey), 'true');

    final restored = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(restored.dispose);
    restored.read(playbackLoopProvider);
    await pumpEventQueue();
    expect(restored.read(playbackLoopProvider), isTrue);
  });

  test('loop leaves novel reader and sequence playback to advance', () async {
    await container.read(playbackLoopProvider.notifier).set(true);
    final notifier = container.read(playbackNotifierProvider.notifier);
    await notifier.load(
      'n.wav',
      'N',
      sourceTag: novelReaderPlaybackSourceFor('project'),
    );
    await finishClip();
    expect(player.played, ['n.wav']);

    player.played.clear();
    final sequence = notifier.playSequenceFrom([
      (audioPath: '1.wav', title: '1', subtitle: null),
      (audioPath: '2.wav', title: '2', subtitle: null),
    ], sourceTag: 'dialog');
    await pumpEventQueue();
    await finishClip();
    await finishClip();
    await sequence;
    expect(player.played, ['1.wav', '2.wav']);
  });

  test('download names come from the clip title', () {
    expect(audioDownloadFileName('你好/世界?', '.wav'), 'neiroha-你好 世界.wav');
    expect(audioDownloadFileName('  ', 'mp3'), 'neiroha-audio.mp3');
    expect(audioDownloadFileName(null, ''), 'neiroha-audio.wav');
    expect(audioDownloadFileName('a' * 60, '.wav'), 'neiroha-${'a' * 40}.wav');
  });
}
