import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/audio/pcm_sequence_adapter.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/synthesis/synthesis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/server/speech_stream_response.dart';
import 'package:neiroha/server/tracked_http_server.dart';
import 'support/novel_fixture.dart';
import 'support/pcm_test_adapters.dart';

class _OddPcm extends FinitePcm {
  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    yield const TtsAudioStarted(
      TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
    );
    yield TtsAudioChunk(Uint8List.fromList([1, 0, 2]));
    yield const TtsSynthesisCompleted();
  }
}

void main() {
  late db.AppDatabase database;
  late db.TtsProvider provider;
  const request = TtsRequest(
    text: '原文',
    voice: 'voice-a',
    responseFormat: 'pcm',
  );
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
  });
  tearDown(() => database.close());

  test(
    'PCM utterance boundaries reject individually truncated frames even when the total is even',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pcm_boundaries_',
      );
      addTearDown(() => directory.delete(recursive: true));
      await expectLater(
        SynthesisService(TtsQueueService.instance).generate(
          provider: provider,
          request: request,
          outputBase: '${directory.path}/audio',
          cancellation: TtsCancelToken(),
          adapter: PcmSequenceAdapter(_OddPcm(), [request, request]),
        ),
        throwsFormatException,
      );
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'continuation respects the daily budget and its long wait is immediately cancellable',
    () async {
      final queue = TtsQueueService.instance;
      final limited = provider.copyWith(
        id: 'continuation-budget',
        requestsPerDay: const Value(1),
      );
      await queue.enqueue(
        provider: limited,
        task: () async {
          final cancellation = TtsCancelToken();
          final future = queue.accountContinuation(
            limited,
            request,
            cancellation,
          );
          final timer = Timer(
            const Duration(milliseconds: 10),
            cancellation.cancel,
          );
          try {
            await expectLater(future, throwsA(isA<TtsCancelledException>()));
          } finally {
            timer.cancel();
          }
        },
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'changed unlocked text can be relabeled after its manual version expires',
    () async {
      final source = (await database.getNovelSegments('book')).first;
      final characters = CharacterRepository(database);
      final speaker = await characters.saveCharacter(
        projectId: 'book',
        name: '甲',
      );
      final annotations = AnnotationRepository(database);
      await annotations.apply('book', [
        SegmentAnnotation(
          segmentId: source.id,
          projectId: 'book',
          textRevision: novelTextRevision(source.segmentText),
          characterId: speaker,
        ),
      ]);
      final changed = source.copyWith(segmentText: '正文已经变化。');
      await database.updateNovelSegment(changed);
      expect(
        await annotations.apply('book', [
          SegmentAnnotation(
            segmentId: source.id,
            projectId: 'book',
            textRevision: novelTextRevision(changed.segmentText),
            kind: NovelSegmentKind.system,
          ),
        ], fromAi: true),
        1,
      );
      expect(
        (await characters.load('book')).annotations[source.id]!.kind,
        NovelSegmentKind.system,
      );
    },
  );

  test(
    'stopping the API also closes taken-over audio sockets and cancels inference',
    () async {
      final adapter = StallingPcm();
      final api = await serveTrackedHttp(
        (request_) => streamSpeechResponse(
          provider: provider,
          request: request,
          adapter: adapter,
          clientClosed:
              request_.context[clientClosedContextKey] as Future<void>?,
        ),
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => api.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(
        Uri.parse('http://127.0.0.1:${api.port}/speech'),
      )).close();
      final first = Completer<void>();
      final subscription = response.listen((_) {
        if (!first.isCompleted) first.complete();
      }, onError: (Object _) {});
      addTearDown(subscription.cancel);
      await first.future.timeout(const Duration(seconds: 3));
      await api.close(force: true);
      await adapter.cancelled.future.timeout(const Duration(seconds: 3));
    },
  );
}
