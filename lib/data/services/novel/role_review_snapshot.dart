import 'dart:convert';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'role_preferences.dart';
import 'character_repository.dart';
import 'role_analysis_context.dart';
import 'role_doubt_detector.dart';
import 'novel_text_revision.dart';

class RoleReviewSnapshot {
  RoleReviewSnapshot(
    this.projectId,
    this.chapterId,
    this.work,
    this.roles,
    this.preferences,
    this.signature,
  ) : chapter = work.where((s) => s.chapterId == chapterId).toList();
  final String projectId, chapterId, signature;
  final List<db.NovelSegment> work, chapter;
  final NovelRoleSnapshot roles;
  final Map<String, dynamic> preferences;
  late final chapterIds = chapter.map((s) => s.id).toSet();
  static Future<RoleReviewSnapshot> load(
    db.AppDatabase database,
    String projectId,
    String chapterId,
    NovelRoleSkill skill,
  ) => database.transaction(() async {
    if (!(await database.getNovelChapters(
      projectId,
    )).any((c) => c.id == chapterId)) {
      throw StateError('Unknown review chapter.');
    }
    final work = await database.getNovelSegments(projectId);
    final roles = await CharacterRepository(database).load(projectId);
    final preferences = await RolePreferences(database).load(projectId);
    final project = (await database.getNovelProjectById(projectId))!;
    final members = await database.getBankMembers(project.bankId);
    final voiceIds = members.map((m) => m.voiceAssetId).toSet();
    final voices = (await database.getAllVoiceAssets())
        .where((v) => voiceIds.contains(v.id))
        .toList();
    final signature = novelTextRevision(
      jsonEncode([
        skill.identity,
        project.bankId,
        project.narratorVoiceAssetId,
        project.dialogueVoiceAssetId,
        [
          for (final m in members) [m.id, m.voiceAssetId],
        ],
        [for (final v in voices) v.toJson()],
        [
          for (final s in work)
            [s.id, s.chapterId, novelTextRevision(s.segmentText)],
        ],
        [
          for (final c in roles.characters)
            [c.id, c.name, c.aliases, c.description, c.identityKind.name],
        ],
        [
          for (final a in roles.annotations.values)
            [
              a.segmentId,
              a.textRevision,
              a.changeId,
              a.characterId,
              a.kind.name,
              a.locked,
              a.reviewState.name,
              a.voiceAssetId,
              a.instruction,
              a.reason,
            ],
        ],
        [
          for (final b in roles.bindings)
            [
              b.characterId,
              b.chapterId,
              b.kind?.name,
              b.voiceAssetId,
              b.instruction,
            ],
        ],
        preferences,
      ]),
    );
    return RoleReviewSnapshot(
      projectId,
      chapterId,
      work,
      roles,
      preferences,
      signature,
    );
  });
  bool editable(String id) {
    final a = roles.annotations[id];
    return chapterIds.contains(id) &&
        !(a?.locked ?? false) &&
        a?.reviewState != NovelReviewState.confirmed;
  }

  List<String> selectTargets([List<String>? requested]) {
    if (requested != null &&
        (requested.isEmpty ||
            requested.length > 8 ||
            requested.toSet().length != requested.length ||
            requested.any((id) => !editable(id)))) {
      throw ArgumentError(
        'Choose up to eight unconfirmed, unlocked chapter segments.',
      );
    }
    final context = RoleAnalysisContext(chapter);
    final labels = roles.annotations.values
        .where((a) => editable(a.segmentId))
        .toList();
    final doubtful = RoleDoubtDetector.inspect(
      labels: labels,
      roles: roles,
      context: context,
    ).where((d) => !d.auditOnly).map((d) => d.segmentId).toSet();
    final candidates =
        requested ??
        [
          for (final s in chapter)
            if (editable(s.id) && doubtful.contains(s.id)) s.id,
          for (final s in chapter)
            if (editable(s.id) && !doubtful.contains(s.id)) s.id,
        ];
    final chosen = <String>[];
    var length = 0;
    for (final id in candidates) {
      final text = chapter.firstWhere((s) => s.id == id).segmentText;
      if (text.length > 2000 || length + text.length > 1500) {
        if (requested != null) {
          throw StateError('Split long review text or select fewer segments.');
        }
        continue;
      }
      chosen.add(id);
      length += text.length;
      if (chosen.length == 8) break;
    }
    if (chosen.isEmpty) throw StateError('No eligible local review targets.');
    return chosen;
  }

  Map<String, Object?> segment(db.NovelSegment s, {int? limit}) {
    final a = roles.annotations[s.id];
    return {
      'id': s.id,
      'text': limit == null
          ? s.segmentText
          : RoleAnalysisContext.excerpt(s.segmentText, limit),
      'truncated': limit != null && s.segmentText.length > limit,
      'editable': editable(s.id),
      'characterId': a?.characterId,
      'kind': a?.kind.name ?? s.segmentType,
      'review': a?.reviewState.name,
      'reason': a?.reason,
    };
  }

  List<Map<String, Object?>> castFor(List<String> targets) {
    final relevant = targets
        .map((id) => roles.annotations[id]?.characterId)
        .whereType<String>()
        .toSet();
    final ordered = [
      ...roles.characters.where((c) => relevant.contains(c.id)),
      ...roles.characters.where((c) => !relevant.contains(c.id)),
    ];
    final out = <Map<String, Object?>>[];
    var bytes = 0;
    for (final c in ordered) {
      final entry = {
        'id': c.id,
        'name': c.name,
        'aliases': c.aliases.take(3).toList(),
        'identityKind': c.identityKind.name,
      };
      final size = utf8.encode(jsonEncode(entry)).length;
      if (bytes + size > 2500) continue;
      out.add(entry);
      bytes += size;
      if (out.length == 15) break;
    }
    return out;
  }

  db.NovelSegment requireSegment(String id) =>
      chapter.where((s) => s.id == id).firstOrNull ??
      (throw ArgumentError('Segment outside this chapter.'));
  StoryCharacter requireCharacter(String id) =>
      roles.characters.where((c) => c.id == id).firstOrNull ??
      (throw ArgumentError('Character outside this novel.'));
}
