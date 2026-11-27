import 'dart:io';

import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/storage/path_service.dart';

import '../speech_resolver.dart';
import 'jobs_handler.dart';
import 'speech_job_store.dart';

export 'jobs_handler.dart';

/// The `/v1/jobs` endpoints, synthesizing through the global TTS queue.
/// Jobs live in [dir] (default `<data root>/api_jobs`), opened on first use.
JobsHandler speechJobs(AppDatabase db, {Directory? dir}) {
  Future<SpeechJobStore>? opened;
  Future<SpeechJobStore> store() => opened ??= () async {
    final root =
        dir ?? Directory('${PathService.instance.dataRoot.path}/api_jobs');
    final store = SpeechJobStore(
      root,
      run: (body, cancellation) async {
        final speech = await resolveSpeech(db, body);
        return TtsQueueService.instance.synthesize(
          provider: speech.provider,
          modelName: speech.asset.modelName,
          source: 'External API job',
          label: '${speech.request.voice}: ${speech.request.text}',
          request: speech.request,
          cancelToken: cancellation,
        );
      },
    );
    await store.open();
    return store;
  }();
  return JobsHandler(store, validate: (body) => resolveSpeech(db, body));
}
