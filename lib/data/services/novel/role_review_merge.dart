import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'annotation_repository.dart';
import 'character_repository.dart';
import 'role_preferences.dart';
import 'role_review_snapshot.dart';
import 'novel_text_revision.dart';

class RoleReviewMerge {
  static List<SegmentAnnotation> validate(
    RoleReviewSnapshot state,
    String from,
    String into,
  ) {
    if (from == into) {
      throw ArgumentError('Merge needs two distinct identities.');
    }
    final a = state.requireCharacter(from), b = state.requireCharacter(into);
    if ((a.identityKind == CharacterIdentityKind.group) !=
        (b.identityKind == CharacterIdentityKind.group)) {
      throw StateError('A group cannot be merged into an individual.');
    }
    final affected = state.roles.annotations.values
        .where((a) => a.characterId == from)
        .toList();
    if (affected.length > 30) {
      throw StateError(
        'Merge affects more than 30 labels; use manual character tools.',
      );
    }
    if (affected.any(
      (a) => a.locked || a.reviewState == NovelReviewState.confirmed,
    )) {
      throw StateError(
        'Merge would change a locked or manually confirmed identity.',
      );
    }
    final rows = {for (final row in state.work) row.id: row};
    if (affected.any(
      (a) =>
          rows[a.segmentId] == null ||
          a.textRevision != novelTextRevision(rows[a.segmentId]!.segmentText),
    )) {
      throw StateError(
        'Merge contains outdated labels; review the changed text first.',
      );
    }
    for (final source in state.roles.bindings.where(
      (b) => b.characterId == from,
    )) {
      final targets = state.roles.bindings.where(
        (b) =>
            b.characterId == into &&
            b.chapterId == source.chapterId &&
            b.kind == source.kind,
      );
      if (targets.isEmpty &&
          state.roles.annotations.values.any((a) => a.characterId == into)) {
        throw StateError(
          'Moving a voice/style would change target fallback playback; resolve the binding manually first.',
        );
      }
      if (targets.any(
        (b) =>
            b.voiceAssetId != source.voiceAssetId ||
            b.instruction != source.instruction,
      )) {
        throw StateError(
          'Merge has conflicting voice/style bindings; resolve them manually.',
        );
      }
    }
    return affected;
  }

  static Future<int> apply(
    db.AppDatabase database,
    RoleReviewSnapshot state,
    String from,
    String into,
  ) async {
    final affected = validate(state, from, into);
    final characters = CharacterRepository(database);
    final preferences = RolePreferences(database);
    for (final binding in state.roles.bindings.where(
      (b) => b.characterId == from,
    )) {
      if (binding.kind == null) {
        await characters.bindVoice(
          projectId: state.projectId,
          characterId: into,
          voiceAssetId: binding.voiceAssetId,
          chapterId: binding.chapterId,
          instruction: binding.instruction,
        );
      } else {
        await preferences.setStyle(
          projectId: state.projectId,
          characterId: into,
          kind: binding.kind!,
          chapterId: binding.chapterId,
          voiceAssetId: binding.voiceAssetId.isEmpty
              ? null
              : binding.voiceAssetId,
          instruction: binding.instruction,
        );
      }
    }
    final rows = {for (final row in state.work) row.id: row};
    final applied = await AnnotationRepository(database).apply(state.projectId, [
      for (final a in affected)
        SegmentAnnotation(
          segmentId: a.segmentId,
          projectId: state.projectId,
          textRevision: novelTextRevision(rows[a.segmentId]!.segmentText),
          characterId: into,
          kind: a.kind,
          voiceAssetId: a.voiceAssetId,
          instruction: a.instruction,
          reviewState: NovelReviewState.inferred,
          reason:
              'Accepted AI identity merge; manual confirmation still required.',
        ),
    ], fromAi: true);
    final source = state.requireCharacter(from),
        target = state.requireCharacter(into);
    final aliases = {...target.aliases, source.name, ...source.aliases}
      ..remove(target.name);
    await (database.update(
      database.novelCharacters,
    )..where((t) => t.id.equals(into))).write(
      db.NovelCharactersCompanion(
        aliasesJson: Value(jsonEncode(aliases.toList())),
      ),
    );
    final data = await preferences.load(state.projectId);
    (data['identities'] as Map).remove(from);
    (data['styles'] as List).removeWhere((s) => s['characterId'] == from);
    await database.setSetting(
      preferences.key(state.projectId),
      jsonEncode(data),
    );
    await (database.delete(
      database.novelVoiceBindings,
    )..where((t) => t.characterId.equals(from))).go();
    await (database.delete(
      database.novelCharacters,
    )..where((t) => t.id.equals(from))).go();
    // Keep narrator/scene references coherent with the accepted identity.
    for (final chapter in await database.getNovelChapters(state.projectId)) {
      final key = 'novel.roleAnalysis.${state.projectId}.${chapter.id}';
      final raw = await database.getSetting(key);
      if (raw == null) continue;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final scene = saved['scene'];
      if (scene is! Map) continue;
      if (scene['firstPersonId'] == from) scene['firstPersonId'] = into;
      for (final field in ['presentCharacterIds', 'nestedNarratorIds']) {
        if (scene[field] is List) {
          scene[field] = (scene[field] as List)
              .map((id) => id == from ? into : id)
              .toSet()
              .toList();
        }
      }
      await database.setSetting(key, jsonEncode(saved));
    }
    return applied;
  }
}
