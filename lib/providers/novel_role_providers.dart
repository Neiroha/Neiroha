import 'model_capability_providers.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/novel/role_analysis_checkpoint.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';

import 'app_providers.dart';
import 'package:neiroha/data/services/novel/novel_structure_editor.dart';
import 'package:neiroha/data/services/novel/role_preferences.dart';
import 'package:neiroha/data/services/novel/character_split_service.dart';
import 'package:neiroha/data/services/novel/role_direction_service.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/data/services/novel/novel_streaming_service.dart';

final novelStreamingServiceProvider = Provider(
  (ref) => NovelStreamingService(
    ref.watch(databaseProvider),
    ref.watch(storageServiceProvider),
    ref.watch(synthesisServiceProvider),
    ref.watch(autoLoudnessServiceProvider),
  ),
);

final taskProfileRepositoryProvider = Provider(
  (ref) => TaskProfileRepository(ref.watch(databaseProvider)),
);
final novelTaskProfilesProvider = StreamProvider.family(
  (ref, String id) => ref.watch(taskProfileRepositoryProvider).watch(id),
);

final roleDirectionServiceProvider = Provider(
  (ref) => RoleDirectionService(
    ref.watch(databaseProvider),
    ref.watch(ttsQueueServiceProvider),
  ),
);

final novelStructureEditorProvider = Provider(
  (ref) => NovelStructureEditor(ref.watch(databaseProvider)),
);
final rolePreferencesProvider = Provider(
  (ref) => RolePreferences(ref.watch(databaseProvider)),
);
final characterSplitServiceProvider = Provider(
  (ref) => CharacterSplitService(ref.watch(databaseProvider)),
);

final characterRepositoryProvider = Provider(
  (ref) => CharacterRepository(ref.watch(databaseProvider)),
);
final annotationRepositoryProvider = Provider(
  (ref) => AnnotationRepository(ref.watch(databaseProvider)),
);
final novelRoleSnapshotProvider = StreamProvider.family(
  (ref, String projectId) =>
      ref.watch(characterRepositoryProvider).watch(projectId),
);

final roleAnalysisServiceProvider = Provider((ref) {
  final service = RoleAnalysisService(
    ref.watch(databaseProvider),
    ref.watch(characterRepositoryProvider),
    ref.watch(annotationRepositoryProvider),
    ref.watch(ttsQueueServiceProvider),
    capabilities: ref.watch(capabilityRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
final roleAnalysisCheckpointProvider =
    StreamProvider.family<
      RoleAnalysisCheckpoint?,
      ({String projectId, String chapterId})
    >(
      (ref, key) => ref
          .watch(roleAnalysisServiceProvider)
          .checkpoints
          .watch(key.projectId, key.chapterId),
    );
