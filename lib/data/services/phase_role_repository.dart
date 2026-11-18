import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'novel/novel_text_revision.dart';
import 'novel/role_skill_profiles_repository.dart';

class PhaseRoleRepository {
  PhaseRoleRepository(this.database, this.skills);
  final db.AppDatabase database;
  final RoleSkillProfilesRepository skills;
  Future<String> signature(String projectId) => database.transaction(() async {
    final project = await database.getPhaseTtsProjectById(projectId);
    if (project == null) throw StateError('Long-text project was deleted.');
    final members = await database.getBankMembers(project.bankId);
    final voices = (await database.getAllVoiceAssets()).where(
      (a) => members.any((m) => m.voiceAssetId == a.id),
    );
    return novelTextRevision(
      jsonEncode([
        project.toJson(),
        [
          for (final s in await database.getPhaseTtsSegments(projectId))
            s.toJson(),
        ],
        [for (final m in members) m.toJson()],
        [for (final a in voices) a.toJson()],
        (await skills.loadSkill()).identity,
      ]),
    );
  });
  Future<void> apply({
    required String projectId,
    required String expectedSignature,
    required TextRolePlan plan,
    required Map<String, String?> voices,
  }) => database.transaction(() async {
    plan.validate();
    final project = await database.getPhaseTtsProjectById(projectId);
    if (project == null ||
        project.scriptText != plan.text ||
        expectedSignature != await signature(projectId) ||
        plan.skillDigest != (await skills.loadSkill()).digest) {
      throw StateError(
        'Text, segments, voice bank or role configuration changed. Analyze again.',
      );
    }
    final keys = plan.units.map((u) => u.voiceKey).toSet();
    final members = (await database.getBankMembers(
      project.bankId,
    )).map((m) => m.voiceAssetId).toSet();
    final enabled = (await database.getAllVoiceAssets())
        .where((a) => a.enabled && members.contains(a.id))
        .map((a) => a.id)
        .toSet();
    if (voices.keys.any((k) => !keys.contains(k)) ||
        voices.values.whereType<String>().any((v) => !enabled.contains(v))) {
      throw ArgumentError('Choose enabled voices from this project bank.');
    }
    // References in existing timelines must not silently change to another text.
    final clips = await database.select(database.timelineClips).get();
    if (clips.any(
      (c) => c.projectId == projectId && c.projectType == 'phase',
    )) {
      throw StateError(
        'Existing timeline clips use these segments. Remove those references before replacing the segmentation.',
      );
    }
    await database.clearPhaseTtsSegments(projectId);
    final names = {for (final c in plan.characters) c.id: c.name};
    for (var i = 0; i < plan.units.length; i++) {
      final unit = plan.units[i];
      await database.insertPhaseTtsSegment(
        db.PhaseTtsSegmentsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(projectId),
          orderIndex: Value(i),
          segmentText: Value(unit.text),
          speakerLabel: Value(names[unit.characterId] ?? unit.kind.name),
          voiceAssetId: Value(voices[unit.voiceKey]),
        ),
      );
    }
    await database.setSetting(
      'phase.roleAnalysis.$projectId',
      jsonEncode({
        'version': 1,
        'skillDigest': plan.skillDigest,
        'calls': plan.calls,
        'units': [
          for (final u in plan.units)
            {
              'start': u.start,
              'end': u.end,
              'kind': u.kind.name,
              'characterId': u.characterId,
              'review': u.review.name,
              'reason': u.reason,
              if (u.manuallyEdited) 'manuallyEdited': true,
            },
        ],
        'characters': [
          for (final c in plan.characters)
            {'id': c.id, 'name': c.name, 'aliases': c.aliases},
        ],
      }),
    );
    await database.updatePhaseTtsProject(
      project.copyWith(updatedAt: DateTime.now()),
    );
  });
}
