import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// The reader advances only after audible drain or file completion. A global
/// stop or another playback source cancels this sentence rather than advancing.
Future<void> playNovelSentence({
  required WidgetRef ref,
  required db.NovelProject project,
  required db.NovelSegment segment,
  required TtsCancelToken cancellation,
  required bool cacheOnly,
  required bool force,
  required String subtitle,
  required String sourceTag,
  required void Function() onFirstAudio,
  required Future<String> Function() ensureFile,
}) async {
  final service = ref.read(novelStreamingServiceProvider);
  final player = ref.read(playbackNotifierProvider.notifier);
  final filePlayer = ref.read(audioPlayerProvider);
  var latest = ref.read(playbackNotifierProvider);
  var started = false;
  final subscription = ref.listenManual(playbackNotifierProvider, (
    previous,
    next,
  ) {
    latest = next;
    if (started &&
        previous?.sourceTag == sourceTag &&
        next.sourceTag != sourceTag) {
      cancellation.cancel();
    }
  });
  try {
    final plan = await service.prepare(project, segment);
    cancellation.throwIfCancelled();
    started = true;
    if (!cacheOnly && plan.canStream && (force || plan.cachedPath == null)) {
      Future<void>? drained;
      await player.playSynthesis(
        title: segment.segmentText,
        subtitle: subtitle,
        sourceTag: sourceTag,
        cancellation: cancellation,
        generate: (sink) {
          drained = sink.drained;
          return service.generate(
            plan,
            cancellation: cancellation,
            sink: sink,
            onFirstAudio: onFirstAudio,
          );
        },
      );
      await drained;
      cancellation.throwIfCancelled();
      return;
    }
    final path = !force ? plan.cachedPath : null;
    final file =
        path ??
        (cacheOnly
            ? throw StateError('Current cached sentence is missing.')
            : await ensureFile());
    cancellation.throwIfCancelled();
    final completed = Completer<void>();
    final audioEvents = filePlayer.onPlayerComplete.listen((_) {
      if (!completed.isCompleted &&
          latest.audioPath == file &&
          latest.sourceTag == sourceTag) {
        completed.complete();
      }
    });
    final remove = cancellation.onCancel(() {
      if (!completed.isCompleted) {
        completed.completeError(const TtsCancelledException());
      }
    });
    try {
      await Future.wait<void>([
        completed.future,
        () async {
          await player.load(
            file,
            segment.segmentText,
            subtitle: subtitle,
            sourceTag: sourceTag,
          );
          onFirstAudio();
        }(),
      ], eagerError: true);
    } finally {
      remove();
      await audioEvents.cancel();
    }
  } finally {
    subscription.close();
  }
}
