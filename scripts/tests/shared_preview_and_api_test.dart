import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/auto_loudness_service.dart';
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/data/services/synthesis/sentence_preview_service.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/server/speech_request_handler.dart';
import 'package:neiroha/server/speech_stream_response.dart';
import 'package:neiroha/server/tracked_http_server.dart';
import 'support/memory_audio_sink.dart';
import 'support/pcm_test_adapters.dart';
import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  late Directory directory;
  late HttpServer server;
  late db.TtsProvider provider;
  late StorageService storage;
  late SentencePreviewService preview;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('neiroha_工程 preview_');
    PathService.instance.applyVoiceAssetRootOverride(directory.path);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
    provider = provider.copyWith(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      defaultModelName: 'gateway-speech',
    );
    await database.updateProvider(provider);
    storage = StorageService(database);
    preview = SentencePreviewService(
      database,
      storage,
      SynthesisService(TtsQueueService.instance),
      AutoLoudnessService(db: database, ffmpeg: FFmpegService(database)),
    );
    final now = DateTime(2026, 11, 17);
    await database
        .into(database.dialogTtsProjects)
        .insert(
          db.DialogTtsProjectsCompanion.insert(
            id: 'dialog',
            name: '对话 中文',
            bankId: 'bank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.dialogTtsLines)
        .insert(
          db.DialogTtsLinesCompanion.insert(
            id: 'dialog-line',
            projectId: 'dialog',
            orderIndex: 0,
            lineText: '对话原文',
            voiceAssetId: const Value('voice-a'),
          ),
        );
    await database
        .into(database.phaseTtsProjects)
        .insert(
          db.PhaseTtsProjectsCompanion.insert(
            id: 'phase',
            name: '长文本 中文',
            bankId: 'bank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.phaseTtsSegments)
        .insert(
          db.PhaseTtsSegmentsCompanion.insert(
            id: 'phase-line',
            projectId: 'phase',
            orderIndex: 0,
            segmentText: '长文本原文',
            voiceAssetId: const Value('voice-a'),
          ),
        );
    await database
        .into(database.videoDubProjects)
        .insert(
          db.VideoDubProjectsCompanion.insert(
            id: 'video',
            name: '视频 中文',
            bankId: 'bank',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.subtitleCues)
        .insert(
          db.SubtitleCuesCompanion.insert(
            id: 'video-line',
            projectId: 'video',
            orderIndex: 0,
            startMs: 0,
            endMs: 1000,
            cueText: '字幕原文',
            voiceAssetId: const Value('voice-a'),
          ),
        );
  });
  tearDown(() async {
    await server.close(force: true);
    await database.close();
    PathService.instance.applyVoiceAssetRootOverride(null);
    await directory.delete(recursive: true);
  });

  for (final kind in SentenceProjectKind.values) {
    test(
      '${kind.name} preview streams and publishes one complete exportable clip',
      () async {
        Map<String, dynamic>? input;
        server.listen((request) async {
          input =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.add([1, 0, 2, 0, 3, 0]);
          await request.response.close();
        });
        if (kind == SentenceProjectKind.phase) {
          final slug = await storage.ensurePhaseProjectSlug('phase');
          await PhaseSegmentSettingsFileService().save(
            slug,
            const PhaseSegmentSettings(
              bySegmentId: {
                'phase-line': SegmentVoiceSettings(voiceInstruction: '低声、迟疑'),
              },
            ),
          );
        }
        final sink = MemoryAudioSink();
        final receipt = await preview.generate(
          kind: kind,
          projectId: kind.name,
          id: '${kind.name}-line',
          cancellation: TtsCancelToken(),
          sink: sink,
        );
        expect(sink.finished, true);
        expect((await File(receipt.audioPath).readAsBytes()).sublist(44), [
          1,
          0,
          2,
          0,
          3,
          0,
        ]);
        expect(receipt.audioPath.startsWith(directory.path), true);
        expect(input!['response_format'], 'pcm');
        if (kind == SentenceProjectKind.phase) {
          expect(input!['instructions'], '低声、迟疑');
        }
        final row = await database
            .customSelect(
              'SELECT audio_path, audio_duration, missing FROM '
              '${switch (kind) {
                SentenceProjectKind.dialog => 'dialog_tts_lines',
                SentenceProjectKind.phase => 'phase_tts_segments',
                SentenceProjectKind.video => 'subtitle_cues',
              }}',
            )
            .getSingle();
        expect(row.read<String>('audio_path'), receipt.audioPath);
        expect(
          row.read<double>('audio_duration'),
          closeTo(3 / 24000, 0.000001),
        );
        expect(row.read<int>('missing'), 0);
        // Complete the fake speaker lifecycle before closing its database.
        await sink.stop();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
    );
  }

  test('late preview does not restore edited project text', () async {
    final release = Completer<void>();
    server.listen((request) async {
      await request.drain<void>();
      request.response.bufferOutput = false;
      request.response.add([1, 0]);
      await request.response.flush();
      await release.future;
      request.response.add([2, 0]);
      await request.response.close();
    });
    final sink = MemoryAudioSink();
    final result = preview.generate(
      kind: SentenceProjectKind.dialog,
      projectId: 'dialog',
      id: 'dialog-line',
      cancellation: TtsCancelToken(),
      sink: sink,
    );
    await sink.firstChunk.future.timeout(const Duration(seconds: 3));
    final source = (await database.getDialogTtsLines('dialog')).single;
    await database.updateDialogTtsLine(source.copyWith(lineText: '后来编辑的正文'));
    final rejected = expectLater(result, throwsA(isA<TtsCancelledException>()));
    release.complete();
    await rejected;
    final row = (await database.getDialogTtsLines('dialog')).single;
    expect(row.lineText, '后来编辑的正文');
    expect(row.audioPath, isNull);
  });

  test(
    'API PCM headers use declared rate and disconnect cancels the upstream',
    () async {
      final adapter = StallingPcm();
      final response = await streamSpeechResponse(
        provider: provider,
        request: const TtsRequest(
          text: '测试',
          voice: 'voice-a',
          responseFormat: 'pcm',
        ),
        adapter: adapter,
      );
      expect(response.headers['x-audio-sample-rate'], '22050');
      final chunks = await response.read().take(1).toList();
      expect(chunks.single, [1, 0, 2, 0]);
      await adapter.cancelled.future.timeout(const Duration(seconds: 3));
    },
  );

  test(
    'file API remains WAV-compatible and non-PCM streaming is rejected before inference',
    () async {
      var calls = 0;
      server.listen((request) async {
        calls++;
        await request.drain<void>();
        request.response.add([1, 0, 2, 0]);
        await request.response.close();
      });
      final handler = SpeechRequestHandler(database);
      final rejected = await handler.handle(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/audio/speech'),
          body: jsonEncode({
            'input': '文本',
            'voice': 'voice-a',
            'stream': true,
            'response_format': 'mp3',
          }),
        ),
      );
      expect(rejected.statusCode, 400);
      expect(calls, 0);
      final response = await handler.handle(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/audio/speech'),
          body: jsonEncode({
            'input': '文本',
            'voice': 'voice-a',
            'response_format': 'pcm',
          }),
        ),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'audio/wav');
      final bytes = await response.read().expand((e) => e).toList();
      expect(ascii.decode(bytes.take(4).toList()), 'RIFF');
      expect(bytes.sublist(44), [1, 0, 2, 0]);
      expect(calls, 1);
    },
  );

  test(
    'real HTTP first chunk is unbuffered and disconnect cancels a stalled model',
    () async {
      final adapter = StallingPcm();
      final api = await serveTrackedHttp(
        (request) => streamSpeechResponse(
          provider: provider,
          request: const TtsRequest(
            text: '原文',
            voice: 'voice-a',
            responseFormat: 'pcm',
          ),
          adapter: adapter,
          clientClosed:
              request.context[clientClosedContextKey] as Future<void>?,
        ),
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => api.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${api.port}/speech'),
      );
      final response = await request.close();
      final first = Completer<void>();
      late StreamSubscription<List<int>> subscription;
      subscription = response.listen((data) {
        if (!first.isCompleted) {
          first.complete();
          unawaited(subscription.cancel());
          client.close(force: true);
        }
      });
      await first.future.timeout(const Duration(seconds: 3));
      await adapter.cancelled.future.timeout(const Duration(seconds: 3));
    },
  );

  for (final fail in [false, true]) {
    test(
      'real HTTP ${fail ? 'rejects truncated' : 'completes valid'} chunked audio',
      () async {
        final api = await serveTrackedHttp(
          (request) => streamSpeechResponse(
            provider: provider,
            request: const TtsRequest(
              text: '原文',
              voice: 'voice-a',
              responseFormat: 'pcm',
            ),
            adapter: FinitePcm(fail: fail),
            clientClosed:
                request.context[clientClosedContextKey] as Future<void>?,
          ),
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(() => api.close(force: true));
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:${api.port}/speech'),
        );
        final response = await request.close();
        final bytes = response.fold<List<int>>([], (a, b) => a..addAll(b));
        if (fail) {
          await expectLater(bytes, throwsA(isA<HttpException>()));
        } else {
          expect(await bytes, [1, 0, 2, 0]);
        }
      },
    );
  }
}
