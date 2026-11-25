import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:uuid/uuid.dart';

enum SpeechJobStatus {
  queued,
  running,
  succeeded,
  failed,
  cancelled;

  bool get finished => index >= succeeded.index;
}

/// Synthesizes one job body; throws to fail the job.
typedef SpeechJobRunner =
    Future<TtsResult> Function(
      Map<String, dynamic> body,
      TtsCancelToken cancellation,
    );

/// An asynchronous speech request of the local API.
class SpeechJob {
  SpeechJob._(this.id, this.body, this.createdAt)
    : status = SpeechJobStatus.queued,
      updatedAt = createdAt;

  final String id;

  /// The request body, as for `POST /v1/audio/speech`.
  final Map<String, dynamic> body;
  final DateTime createdAt;
  SpeechJobStatus status;
  DateTime updatedAt;
  DateTime? startedAt;
  DateTime? finishedAt;
  int attempt = 1;
  String? error;
  String? contentType;
  int? audioBytes;
  TtsCancelToken? _cancel;

  String get audioUrl => '/v1/audio/speech/$id';

  Map<String, Object?> toJson() => {
    'id': id,
    'object': 'speech.job',
    'status': status.name,
    'attempt': attempt,
    'input': body['input'],
    'voice': body['voice'],
    if (body['model'] != null) 'model': body['model'],
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (startedAt case final t?) 'started_at': t.toUtc().toIso8601String(),
    if (finishedAt case final t?) 'finished_at': t.toUtc().toIso8601String(),
    if (error != null) 'error': error,
    if (status == SpeechJobStatus.succeeded)
      'result': {
        'content_type': contentType,
        'bytes': audioBytes,
        'url': audioUrl,
      },
  };

  Map<String, Object?> _record() => {...toJson(), 'body': body};

  /// An unchanging copy, so a listener that reads late still sees the
  /// state of the moment it was sent.
  SpeechJob _snapshot() => _fromRecord(jsonDecode(jsonEncode(_record())))!;

  static SpeechJob? _fromRecord(Map<String, dynamic> json) {
    final id = json['id'];
    final body = json['body'];
    final created = DateTime.tryParse('${json['created_at']}');
    if (id is! String || body is! Map || created == null) return null;
    final job = SpeechJob._(id, Map<String, dynamic>.from(body), created)
      ..status =
          SpeechJobStatus.values.asNameMap()[json['status']] ??
          SpeechJobStatus.failed
      ..updatedAt = DateTime.tryParse('${json['updated_at']}') ?? created
      ..startedAt = DateTime.tryParse('${json['started_at']}')
      ..finishedAt = DateTime.tryParse('${json['finished_at']}')
      ..attempt = (json['attempt'] as num?)?.toInt() ?? 1
      ..error = json['error'] as String?;
    final result = json['result'];
    if (result is Map) {
      job
        ..contentType = result['content_type'] as String?
        ..audioBytes = (result['bytes'] as num?)?.toInt();
    }
    return job;
  }
}

/// Jobs of the local API, kept as `<id>.json` (+ `<id>.audio`) in [dir] so
/// they survive a restart. Jobs that were running when the app quit come
/// back failed; the newest [keep] finished jobs are kept.
class SpeechJobStore {
  SpeechJobStore(this.dir, {required this.run, this.keep = 200});
  final Directory dir;
  final SpeechJobRunner run;
  final int keep;

  final _jobs = <String, SpeechJob>{};
  final _changes = StreamController<SpeechJob>.broadcast();
  Future<void>? _opened;

  Future<void> open() => _opened ??= _load();

  Future<void> _load() async {
    if (!await dir.exists()) await dir.create(recursive: true);
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final job = SpeechJob._fromRecord(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>,
        );
        if (job == null) continue;
        if (!job.status.finished) {
          job
            ..status = SpeechJobStatus.failed
            ..error = 'Interrupted: Neiroha quit before the job finished.'
            ..finishedAt = DateTime.now()
            ..updatedAt = DateTime.now();
          await _save(job);
        }
        _jobs[job.id] = job;
      } catch (_) {
        // A damaged record is skipped, not fatal.
      }
    }
  }

  SpeechJob? operator [](String id) => _jobs[id];

  /// Newest first.
  List<SpeechJob> list({int? limit}) {
    final all = _jobs.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return limit == null ? all : all.take(limit).toList();
  }

  /// The job now and at every change, until it finishes. Each event is a
  /// snapshot, and changes are followed from before the first one is sent,
  /// so a slow reader still gets the final state.
  Stream<SpeechJob> watch(String id) {
    final job = _jobs[id];
    if (job == null) return const Stream.empty();
    StreamSubscription<SpeechJob>? changes;
    final out = StreamController<SpeechJob>(onCancel: () => changes?.cancel());
    var last = (job.status, job.attempt);
    out.add(job._snapshot());
    if (job.status.finished) {
      unawaited(out.close());
      return out.stream;
    }
    changes = _changes.stream.listen((changed) {
      if (changed.id != id || (changed.status, changed.attempt) == last) {
        return;
      }
      last = (changed.status, changed.attempt);
      out.add(changed._snapshot());
      if (changed.status.finished) {
        unawaited(changes?.cancel());
        unawaited(out.close());
      }
    });
    return out.stream;
  }

  /// Queues [body] and starts it.
  Future<SpeechJob> create(Map<String, dynamic> body) async {
    await open();
    final job = SpeechJob._(const Uuid().v4(), body, DateTime.now());
    _jobs[job.id] = job;
    await _save(job);
    await _prune();
    await _start(job);
    return job;
  }

  /// Runs a finished job again as a new attempt; null when it is still
  /// queued or running.
  Future<SpeechJob?> retry(String id) async {
    final job = _jobs[id];
    if (job == null || !job.status.finished) return null;
    job
      ..attempt += 1
      ..status = SpeechJobStatus.queued
      ..error = null
      ..contentType = null
      ..audioBytes = null
      ..startedAt = null
      ..finishedAt = null;
    if (await _audio(id).exists()) await _audio(id).delete();
    await _changed(job);
    await _start(job);
    return job;
  }

  /// Cancels a queued / running job, or deletes a finished one. Returns the
  /// cancelled job, or null after a delete (or for an unknown id).
  Future<SpeechJob?> cancelOrDelete(String id) async {
    final job = _jobs[id];
    if (job == null) return null;
    if (!job.status.finished) {
      job._cancel?.cancel();
      await _finish(job, SpeechJobStatus.cancelled);
      return job;
    }
    _jobs.remove(id);
    for (final f in [_record(id), _audio(id)]) {
      if (await f.exists()) await f.delete();
    }
    return null;
  }

  /// The audio of a succeeded job.
  Future<Uint8List?> audio(String id) async {
    final job = _jobs[id];
    if (job?.status != SpeechJobStatus.succeeded) return null;
    final f = _audio(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  /// Starts [job]; completes once its running state is saved, while the
  /// synthesis carries on.
  Future<void> _start(SpeechJob job) async {
    final cancel = job._cancel = TtsCancelToken();
    final attempt = job.attempt;
    bool current() =>
        identical(job._cancel, cancel) &&
        job.attempt == attempt &&
        !job.status.finished;
    job
      ..status = SpeechJobStatus.running
      ..startedAt = DateTime.now();
    // Started before the status is saved; awaited (errors included) below.
    final running = run(job.body, cancel)..ignore();
    await _changed(job);
    unawaited(() async {
      try {
        final result = await running;
        if (!current()) return;
        // Written aside and moved into place only if this attempt is still
        // the job's: a cancel or retry during the write wins.
        final part = File('${_audio(job.id).path}.$attempt.part');
        await part.writeAsBytes(result.audioBytes, flush: true);
        if (!current()) {
          await part.delete().catchError((_) => part);
          return;
        }
        await part.rename(_audio(job.id).path);
        if (!current()) return; // audio() serves succeeded jobs only
        job
          ..contentType = result.contentType
          ..audioBytes = result.audioBytes.length;
        await _finish(job, SpeechJobStatus.succeeded);
      } on TtsCancelledException {
        if (current()) await _finish(job, SpeechJobStatus.cancelled);
      } catch (e) {
        if (!current()) return;
        job.error = e.toString();
        await _finish(job, SpeechJobStatus.failed);
      }
    }());
  }

  Future<void> _finish(SpeechJob job, SpeechJobStatus status) async {
    job
      ..status = status
      ..finishedAt = DateTime.now()
      .._cancel = null;
    await _changed(job);
  }

  Future<void> _changed(SpeechJob job) async {
    job.updatedAt = DateTime.now();
    await _save(job);
    _changes.add(job);
  }

  Future<void> _save(SpeechJob job) =>
      _record(job.id).writeAsString(jsonEncode(job._record()), flush: true);

  Future<void> _prune() async {
    final done = list().where((j) => j.status.finished).toList();
    for (final job in done.skip(keep)) {
      await cancelOrDelete(job.id);
    }
  }

  File _record(String id) => File('${dir.path}/$id.json');
  File _audio(String id) => File('${dir.path}/$id.audio');
}
