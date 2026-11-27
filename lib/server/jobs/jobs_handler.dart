import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../speech_request_handler.dart' show jsonError;
import '../speech_resolver.dart';
import 'speech_job_store.dart';

/// Asynchronous speech jobs of the local API:
///
/// ```text
/// POST   /v1/jobs              create (body as POST /v1/audio/speech)
/// GET    /v1/jobs              list, newest first (?limit=)
/// GET    /v1/jobs/<id>         status
/// DELETE /v1/jobs/<id>         cancel a queued / running job, delete others
/// POST   /v1/jobs/<id>/retry   run a finished job again as a new attempt
/// GET    /v1/jobs/<id>/events  status changes as server-sent events
/// GET    /v1/jobs/<id>/audio   the audio (also GET /v1/audio/speech/<id>)
/// ```
class JobsHandler {
  JobsHandler(this.store, {required this.validate});
  final Future<SpeechJobStore> Function() store;

  /// Checks a body before a job is created (bad voice → 404 right away).
  final Future<void> Function(Map<String, dynamic> body) validate;

  void mount(Router router) {
    router
      ..post('/v1/jobs', _create)
      ..get('/v1/jobs', _list)
      ..get('/v1/jobs/<id>', _status)
      ..delete('/v1/jobs/<id>', _cancel)
      ..post('/v1/jobs/<id>/retry', _retry)
      ..get('/v1/jobs/<id>/events', _events)
      ..get('/v1/jobs/<id>/audio', _audio)
      ..get('/v1/audio/speech/<id>', _audio);
  }

  Future<Response> _create(Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException catch (e) {
      return jsonError(400, 'Invalid JSON: ${e.message}');
    }
    if (body is! Map<String, dynamic>) {
      return jsonError(400, 'Body must be a JSON object');
    }
    if (body['stream'] == true) {
      return jsonError(400, 'Jobs return whole files; omit "stream"');
    }
    try {
      await validate(body);
    } on SpeechApiException catch (e) {
      return jsonError(e.status, e.message);
    }
    final job = await (await store()).create(body);
    return _json(202, job.toJson(), location: '/v1/jobs/${job.id}');
  }

  Future<Response> _list(Request request) async {
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '');
    final jobs = (await store()).list(limit: limit);
    return _json(200, {
      'object': 'list',
      'data': [for (final j in jobs) j.toJson()],
    });
  }

  Future<Response> _status(Request request, String id) async {
    final job = (await store())[id];
    return job == null ? _missing(id) : _json(200, job.toJson());
  }

  Future<Response> _cancel(Request request, String id) async {
    final s = await store();
    if (s[id] == null) return _missing(id);
    final cancelled = await s.cancelOrDelete(id);
    return cancelled == null
        ? _json(200, {'id': id, 'object': 'speech.job', 'deleted': true})
        : _json(200, cancelled.toJson());
  }

  Future<Response> _retry(Request request, String id) async {
    final s = await store();
    if (s[id] == null) return _missing(id);
    final job = await s.retry(id);
    return job == null
        ? jsonError(409, 'Job $id is still running')
        : _json(202, job.toJson());
  }

  Future<Response> _events(Request request, String id) async {
    final s = await store();
    if (s[id] == null) return _missing(id);
    final events = s
        .watch(id)
        .map(
          (job) => utf8.encode(
            'event: status\ndata: ${jsonEncode(job.toJson())}\n\n',
          ),
        );
    return Response.ok(
      events,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
      },
      context: {'shelf.io.buffer_output': false},
    );
  }

  Future<Response> _audio(Request request, String id) async {
    final s = await store();
    final job = s[id];
    if (job == null) return _missing(id);
    if (job.status != SpeechJobStatus.succeeded) {
      return jsonError(409, 'Job $id is ${job.status.name}');
    }
    final bytes = await s.audio(id);
    if (bytes == null) return jsonError(410, 'Audio of job $id is gone');
    return Response.ok(
      bytes,
      headers: {'content-type': job.contentType ?? 'application/octet-stream'},
    );
  }

  Response _missing(String id) => jsonError(404, 'Job $id not found');

  Response _json(int status, Object body, {String? location}) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json', 'location': ?location},
  );
}
