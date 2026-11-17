import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/auto_loudness_service.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/data/services/loudness_normalizer.dart';
import 'package:neiroha/data/services/novel/novel_streaming_service.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'support/memory_audio_sink.dart';
import 'support/novel_fixture.dart';

class _Loudness extends AutoLoudnessService {
  _Loudness(db.AppDatabase database)
    : super(db: database, ffmpeg: FFmpegService(database));
  final normalized = <String>[];
  @override
  Future<LoudnessOutcome?> normalizeGenerated({
    required bool enabled,
    required String path,
    required String bankId,
    String? voiceAssetId,
  }) async {
    if (!enabled) return null;
    normalized.add(path);
    return const LoudnessOutcome.adjusted(1);
  }
}

void main() {
  late db.AppDatabase database;
  late Directory directory;
  late HttpServer server;
  late NovelStreamingService service;
  late _Loudness loudness;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('neiroha_小说 stream_');
    PathService.instance.applyVoiceAssetRootOverride(directory.path);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
    await database.updateProvider(
      provider.copyWith(baseUrl: 'http://127.0.0.1:${server.port}/v1'),
    );
    await TaskProfileRepository(database).save(
      'book',
      const TaskProfile(
        task: ModelTask.synthesis,
        providerId: 'test-provider',
        model: 'alias-speaker',
        route: ServiceRoute.speech,
      ),
    );
    loudness = _Loudness(database);
    service = NovelStreamingService(
      database,
      StorageService(database),
      SynthesisService(TtsQueueService.instance),
      loudness,
    );
  });
  tearDown(() async {
    await server.close(force: true);
    await database.close();
    PathService.instance.applyVoiceAssetRootOverride(null);
    await directory.delete(recursive: true);
  });

  test(
    'novel first audio precedes EOF, one cache is published, normalization waits for drain',
    () async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      var requests = 0;
      server.listen((request) async {
        requests++;
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['model'], 'alias-speaker');
        expect(body['response_format'], 'pcm');
        request.response.bufferOutput = false;
        request.response.add([1, 0, 2, 0]);
        await request.response.flush();
        await release.future;
        request.response.add([3, 0, 4, 0]);
        await request.response.close();
      });
      final project = (await database.getNovelProjectById(
        'book',
      ))!.copyWith(autoNormalizeLoudness: true);
      final source = (await database.getNovelSegments('book')).first;
      final plan = await service.prepare(project, source);
      final sink = MemoryAudioSink();
      final result = service.generate(
        plan,
        cancellation: TtsCancelToken(),
        sink: sink,
      );
      await sink.firstChunk.future.timeout(const Duration(seconds: 3));
      expect((await database.getNovelSegments('book')).first.audioPath, isNull);
      expect(loudness.normalized, isEmpty);
      release.complete();
      final receipt = await result;
      expect(requests, 1);
      expect(sink.finished, true);
      final raw = await File(receipt.audioPath).readAsBytes();
      expect(raw.sublist(44), [1, 0, 2, 0, 3, 0, 4, 0]);
      expect(loudness.normalized, isEmpty);
      final normalized = database
          .watchNovelSegments('book')
          .firstWhere((rows) => rows.first.audioPath != receipt.audioPath);
      sink.playbackEnded.complete();
      final row = (await normalized.timeout(const Duration(seconds: 3))).first;
      expect(row.audioPath, endsWith('.normalized.wav'));
      expect(await File(receipt.audioPath).readAsBytes(), raw);
      expect((await service.prepare(project, row)).cachedPath, row.audioPath);
    },
  );

  test(
    'sliced PCM stays in one lease but accounts for every upstream request',
    () async {
      var requests = 0;
      server.listen((request) async {
        requests++;
        await request.drain<void>();
        request.response.add([1, 0, 2, 0]);
        await request.response.close();
      });
      var source = (await database.getNovelSegments('book')).first;
      source = source.copyWith(
        segmentText: List.filled(12, '原文不改写，按语义句播放。').join(),
      );
      await database.updateNovelSegment(source);
      final project = (await database.getNovelProjectById('book'))!.copyWith(
        autoSliceLongSegments: true,
        maxSliceChars: 20,
        sliceOnlyAtPunctuation: false,
      );
      final plan = await service.prepare(project, source);
      expect(plan.chunks.length, greaterThan(1));
      final receipt = await service.generate(
        plan,
        cancellation: TtsCancelToken(),
      );
      expect(requests, plan.chunks.length);
      final data = await File(receipt.audioPath).readAsBytes();
      expect(data.length, 44 + 4 * requests);
      expect(
        (await database.getNovelSegments('book')).first.segmentText,
        source.segmentText,
      );
    },
  );

  test('cancel removes partial cache and leaves the source pending', () async {
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    server.listen((request) async {
      await request.drain<void>();
      request.response.bufferOutput = false;
      request.response.add([1, 0, 2, 0]);
      await request.response.flush();
      await release.future;
      try {
        await request.response.close();
      } catch (_) {}
    });
    final project = (await database.getNovelProjectById('book'))!;
    final source = (await database.getNovelSegments('book')).first;
    final sink = MemoryAudioSink();
    final cancellation = TtsCancelToken();
    final result = service.generate(
      await service.prepare(project, source),
      cancellation: cancellation,
      sink: sink,
    );
    await sink.firstChunk.future.timeout(const Duration(seconds: 3));
    final failure = expectLater(result, throwsA(isA<TtsCancelledException>()));
    cancellation.cancel();
    await failure;
    expect(sink.stopped, true);
    expect((await database.getNovelSegments('book')).first.audioPath, isNull);
    expect(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.contains('.partial') || f.path.endsWith('.wav')),
      isEmpty,
    );
  });
}
