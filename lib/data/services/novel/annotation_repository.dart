import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:uuid/uuid.dart';

import 'novel_text_revision.dart';

/// Every writer, including AI Reviewer/replanning, must enter through apply.
class AnnotationRepository {
  const AnnotationRepository(this.database);
  final db.AppDatabase database;

  Future<int> apply(
    String projectId,
    List<SegmentAnnotation> patches, {
    bool fromAi = false,
  }) => database.transaction(() async {
    final undo = <Map<String, Object?>>[];
    final seen = <String>{};
    var applied = 0;
    final changeId = const Uuid().v4();
    for (final patch in patches) {
      if (!seen.add(patch.segmentId)) {
        throw ArgumentError('Duplicate segment patch.');
      }
      final segment = await (database.select(
        database.novelSegments,
      )..where((t) => t.id.equals(patch.segmentId))).getSingleOrNull();
      if (segment?.projectId != projectId || patch.projectId != projectId) {
        throw ArgumentError('Unknown segment in this novel.');
      }
      if (patch.textRevision != novelTextRevision(segment!.segmentText)) {
        throw StateError('Novel text changed. Refresh before applying labels.');
      }
      final current = await (database.select(
        database.novelAnnotations,
      )..where((t) => t.segmentId.equals(patch.segmentId))).getSingleOrNull();
      if (fromAi &&
          ((current?.locked ?? false) ||
              (current?.reviewState == NovelReviewState.confirmed.name &&
                  current?.textRevision == patch.textRevision))) {
        continue;
      }
      if (patch.characterId != null) {
        final character = await (database.select(
          database.novelCharacters,
        )..where((t) => t.id.equals(patch.characterId!))).getSingleOrNull();
        if (character?.projectId != projectId) {
          throw ArgumentError('Unknown character in this novel.');
        }
      }
      if (patch.voiceAssetId != null) {
        final project = (await database.getNovelProjectById(projectId))!;
        final members = await database.getBankMembers(project.bankId);
        if (!members.any((m) => m.voiceAssetId == patch.voiceAssetId)) {
          throw ArgumentError('Voice is not in this novel’s bank.');
        }
      }
      undo.add({
        'segmentId': patch.segmentId,
        'revision': patch.textRevision,
        'before': current?.toJson(),
        'after': changeId,
      });
      await database
          .into(database.novelAnnotations)
          .insertOnConflictUpdate(
            db.NovelAnnotationsCompanion.insert(
              segmentId: patch.segmentId,
              projectId: projectId,
              textRevision: patch.textRevision,
              characterId: Value(patch.characterId),
              kind: Value(patch.kind.name),
              voiceAssetId: Value(patch.voiceAssetId),
              instruction: Value(patch.instruction),
              locked: Value(fromAi ? false : patch.locked),
              reviewState: Value(
                fromAi
                    ? (patch.reviewState == NovelReviewState.confirmed
                          ? NovelReviewState.inferred.name
                          : patch.reviewState.name)
                    : NovelReviewState.confirmed.name,
              ),
              reason: Value(patch.reason),
              changeId: changeId,
            ),
          );
      applied++;
    }
    if (!fromAi && undo.isNotEmpty) {
      await database
          .into(database.novelRoleEdits)
          .insert(
            db.NovelRoleEditsCompanion.insert(
              projectId: projectId,
              payload: jsonEncode(undo),
              createdAt: DateTime.now(),
            ),
          );
      // Bound durable undo history; a single action can still cover a range.
      final edits =
          await (database.select(database.novelRoleEdits)
                ..where((t) => t.projectId.equals(projectId))
                ..orderBy([(t) => OrderingTerm.desc(t.id)]))
              .get();
      for (final edit in edits.skip(20)) {
        await (database.delete(
          database.novelRoleEdits,
        )..where((t) => t.id.equals(edit.id))).go();
      }
    }
    return applied;
  });

  Future<bool> undo(String projectId) => database.transaction(() async {
    final edit =
        await (database.select(database.novelRoleEdits)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    if (edit == null) return false;
    final payload = (jsonDecode(edit.payload) as List)
        .cast<Map<String, dynamic>>();
    for (final entry in payload) {
      final id = entry['segmentId'] as String;
      final segment = await (database.select(
        database.novelSegments,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final current = await (database.select(
        database.novelAnnotations,
      )..where((t) => t.segmentId.equals(id))).getSingleOrNull();
      if (segment == null ||
          novelTextRevision(segment.segmentText) != entry['revision'] ||
          current?.changeId != entry['after']) {
        throw StateError(
          'A sentence changed after this edit; undo would overwrite newer work.',
        );
      }
      final before = entry['before'];
      if (before == null) {
        await (database.delete(
          database.novelAnnotations,
        )..where((t) => t.segmentId.equals(id))).go();
      } else {
        await database
            .into(database.novelAnnotations)
            .insertOnConflictUpdate(
              db.NovelAnnotation.fromJson(
                Map<String, dynamic>.from(before as Map),
              ),
            );
      }
    }
    await (database.delete(
      database.novelRoleEdits,
    )..where((t) => t.id.equals(edit.id))).go();
    return true;
  });
}
