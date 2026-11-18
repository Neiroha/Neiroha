import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';

import 'annotation_repository.dart';
import 'character_repository.dart';
import 'novel_text_revision.dart';
import 'role_preferences.dart';

class CharacterSplitService {
  const CharacterSplitService(this.database);
  final db.AppDatabase database;

  Future<String> split({
    required String projectId,
    required String sourceId,
    required String name,
    required List<db.NovelSegment> expected,
  }) => database.transaction(() async {
    if (expected.isEmpty) {
      throw ArgumentError('Select the source character’s segments.');
    }
    final repository = CharacterRepository(database);
    final roles = await repository.load(projectId);
    final source = roles.characters.where((c) => c.id == sourceId).firstOrNull;
    if (source == null) throw ArgumentError('Unknown source character.');
    for (final s in expected) {
      final a = roles.annotations[s.id];
      if (s.projectId != projectId ||
          a?.characterId != sourceId ||
          a?.textRevision != novelTextRevision(s.segmentText)) {
        throw StateError('Character attribution or source text changed.');
      }
    }
    final id = await repository.saveCharacter(
      projectId: projectId,
      name: name,
      description: source.description,
    );
    final preferences = RolePreferences(database);
    await preferences.setIdentity(projectId, id, source.identityKind);
    for (final binding in roles.bindings.where(
      (b) => b.characterId == sourceId,
    )) {
      if (binding.kind == null) {
        await repository.bindVoice(
          projectId: projectId,
          characterId: id,
          voiceAssetId: binding.voiceAssetId,
          chapterId: binding.chapterId,
          instruction: binding.instruction,
        );
      } else {
        await preferences.setStyle(
          projectId: projectId,
          characterId: id,
          kind: binding.kind!,
          chapterId: binding.chapterId,
          voiceAssetId: binding.voiceAssetId.isEmpty
              ? null
              : binding.voiceAssetId,
          instruction: binding.instruction,
        );
      }
    }
    await AnnotationRepository(database).apply(projectId, [
      for (final s in expected)
        SegmentAnnotation(
          segmentId: s.id,
          projectId: projectId,
          textRevision: novelTextRevision(s.segmentText),
          characterId: id,
          kind: roles.annotations[s.id]!.kind,
          voiceAssetId: roles.annotations[s.id]!.voiceAssetId,
          instruction: roles.annotations[s.id]!.instruction,
          locked: roles.annotations[s.id]!.locked,
          reason: 'Manual character split',
        ),
    ]);
    return id;
  });
}
