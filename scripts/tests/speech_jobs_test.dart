// The local API's asynchronous speech jobs (/v1/jobs).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/server/api_server.dart';
import 'package:neiroha/server/jobs/jobs_handler.dart';
import 'package:neiroha/server/jobs/speech_job_store.dart';
import 'package:neiroha/server/speech_resolver.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// A runner the test finishes by hand.
class _Runs {
  final pending = <Completer<TtsResult>>[];
  final tokens = <TtsCancelToken>[];
  Future<TtsResult> call(Map<String, dynamic> body, TtsCancelToken cancel) {
    final done = Completer<TtsResult>();
    pending.add(done);
    tokens.add(cancel);
    cancel.onCancel(() {
      if (!done.isCompleted) done.completeError(const TtsCancelledException());
    });
    return done.future;
  }

  void succeed([int i = 0]) => pending[i].complete(
    TtsResult(
      audioBytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'audio/wav',
    ),
  );
}

void main() {
  late Directory dir;
  late _Runs runs;
  late SpeechJobStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('neiroha_jobs');
    runs = _Runs();
    store = SpeechJobStore(dir, run: runs.call, keep: 3);
    await store.open();
  });
  tearDown(() => dir.delete(recursive: true));

  const body = {'input': '你好', 'voice': 'kiki'};

  /// Completes when the job has finished and its files are written.
  Future<void> finished(String id) => store.watch(id).last;

  group('SpeechJobStore', () {
    test('a job runs, succeeds and keeps its audio on disk', () async {
      final job = await store.create(Map.of(body));
      expect(job.status, SpeechJobStatus.running);
      runs.succeed();
      await finished(job.id);
      expect(job.status, SpeechJobStatus.succeeded);
      expect(await store.audio(job.id), [1, 2, 3]);
      expect(job.toJson()['result'], {
        'content_type': 'audio/wav',
        'bytes': 3,
        'url': '/v1/audio/speech/${job.id}',
      });
    });

    test('cancel stops a running job; retry runs it again', () async {
      final job = await store.create(Map.of(body));
      final cancelled = await store.cancelOrDelete(job.id);
      expect(cancelled?.status, SpeechJobStatus.cancelled);
      expect(runs.tokens.single.isCancelled, isTrue);
      expect(job.status, SpeechJobStatus.cancelled);

      final again = await store.retry(job.id);
      expect(again?.attempt, 2);
      expect(await store.retry(job.id), isNull, reason: 'still running');
      runs.succeed(1);
      await finished(job.id);
      expect(job.status, SpeechJobStatus.succeeded);
      // A finished job is deleted, files and all.
      expect(await store.cancelOrDelete(job.id), isNull);
      expect(store[job.id], isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('a failure keeps the error', () async {
      final job = await store.create(Map.of(body));
      runs.pending.single.completeError(StateError('engine down'));
      await finished(job.id);
      expect(job.status, SpeechJobStatus.failed);
      expect(job.error, contains('engine down'));
    });

    test('jobs survive a restart; unfinished ones come back failed', () async {
      final done = await store.create(Map.of(body));
      runs.succeed();
      await finished(done.id);
      final open = await store.create({'input': 'b', 'voice': 'kiki'});

      final reopened = SpeechJobStore(dir, run: runs.call);
      await reopened.open();
      expect(reopened[done.id]?.status, SpeechJobStatus.succeeded);
      expect(await reopened.audio(done.id), [1, 2, 3]);
      expect(reopened[open.id]?.status, SpeechJobStatus.failed);
      expect(reopened[open.id]?.error, contains('Interrupted'));
      expect(reopened[open.id]?.body['input'], 'b');
    });

    test('only the newest finished jobs are kept', () async {
      for (var i = 0; i < 5; i++) {
        final job = await store.create({'input': '$i', 'voice': 'kiki'});
        runs.succeed(i);
        await finished(job.id);
      }
      await store.create({'input': 'last', 'voice': 'kiki'});
      final kept = store.list();
      expect(kept.where((j) => j.status.finished), hasLength(3));
      expect(kept.first.body['input'], 'last');
    });

    test('watch follows a job until it finishes', () async {
      final job = await store.create(Map.of(body));
      final seen = store.watch(job.id).map((j) => j.status).toList();
      runs.succeed();
      expect(await seen, [SpeechJobStatus.running, SpeechJobStatus.succeeded]);
    });
  });

  group('JobsHandler', () {
    late Handler handler;
    setUp(() {
      final router = Router();
      JobsHandler(
        () async => store,
        validate: (b) async {
          if (b['voice'] != 'kiki') {
            throw SpeechApiException(404, 'Voice "${b['voice']}" not found');
          }
        },
      ).mount(router);
      handler = router.call;
    });

    Future<(int, dynamic)> call(
      String method,
      String path, [
      Object? json,
    ]) async {
      final res = await handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          body: json == null ? null : jsonEncode(json),
        ),
      );
      final text = await res.readAsString();
      final type = res.headers['content-type'] ?? '';
      return (res.statusCode, type.contains('json') ? jsonDecode(text) : text);
    }

    test('create, poll, fetch audio, cancel and retry over HTTP', () async {
      final (status, created) = await call('POST', '/v1/jobs', body);
      expect(status, 202);
      final id = created['id'] as String;
      expect(created['status'], 'running');

      expect((await call('GET', '/v1/jobs/$id/audio')).$1, 409);
      runs.succeed();
      await finished(id);
      final (_, job) = await call('GET', '/v1/jobs/$id');
      expect(job['status'], 'succeeded');
      final audio = await handler(
        Request('GET', Uri.parse('http://localhost/v1/audio/speech/$id')),
      );
      expect(audio.headers['content-type'], 'audio/wav');
      expect(await audio.read().expand((b) => b).toList(), [1, 2, 3]);

      final (retried, again) = await call('POST', '/v1/jobs/$id/retry');
      expect((retried, again['attempt']), (202, 2));
      final (_, cancelled) = await call('DELETE', '/v1/jobs/$id');
      expect(cancelled['status'], 'cancelled');
      final (_, list) = await call('GET', '/v1/jobs?limit=5');
      expect((list['data'] as List).single['id'], id);
    });

    test('bad bodies and unknown jobs are refused', () async {
      expect(
        (await call('POST', '/v1/jobs', {'input': 'x', 'voice': 'no'})).$1,
        404,
      );
      expect(
        (await call('POST', '/v1/jobs', {...body, 'stream': true})).$1,
        400,
      );
      expect((await call('POST', '/v1/jobs', [1])).$1, 400);
      expect((await call('GET', '/v1/jobs/nope')).$1, 404);
      expect((await call('POST', '/v1/jobs/nope/retry')).$1, 404);
      expect(runs.pending, isEmpty);
    });

    test('events stream status changes as SSE', () async {
      final (_, created) = await call('POST', '/v1/jobs', body);
      final res = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/v1/jobs/${created['id']}/events'),
        ),
      );
      expect(res.headers['content-type'], 'text/event-stream');
      final text = res.readAsString();
      runs.succeed();
      final events = (await text).split('\n\n').where((e) => e.isNotEmpty);
      expect(events.map((e) => jsonDecode(e.split('data: ').last)['status']), [
        'running',
        'succeeded',
      ]);
    });
  });

  test('ApiServer serves /v1/jobs and resolves voices first', () async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final server = ApiServer(db: database, jobsDir: dir);
    await server.start(config: ApiServerConfig(port: port, rateLimitPerMin: 0));
    addTearDown(server.stop);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Future<int> send(String method, String path, [Object? json]) async {
      final req = await client.open(method, '127.0.0.1', port, path);
      if (json != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(json));
      }
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode;
    }

    expect(
      await send('POST', '/v1/jobs', {'input': 'x', 'voice': 'ghost'}),
      404,
    );
    expect(await send('GET', '/v1/jobs'), 200);
    expect(await send('GET', '/v1/audio/speech/none'), 404);
  });
}
