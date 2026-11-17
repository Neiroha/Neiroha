import 'dart:convert';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'role_review_snapshot.dart';
import 'role_review_merge.dart';
import 'role_review_tools.dart';
import 'role_skill_repository.dart';
import 'role_skill_profiles_repository.dart';
import 'character_repository.dart';
import 'annotation_repository.dart';
import 'novel_text_revision.dart';

class RoleReviewRepository {
  RoleReviewRepository(this.database, {RoleSkillLoader? loadSkill})
    : _loadSkill = loadSkill ?? RoleSkillProfilesRepository(database).loadSkill;
  final db.AppDatabase database;
  final RoleSkillLoader _loadSkill;
  String key(String projectId, String chapterId) =>
      'novel.toolReview.$projectId.$chapterId';
  String historyKey(String id) => 'novel.toolReviewHistory.$id';
  Future<RoleReviewSession?> load(String projectId, String chapterId) async {
    final raw = await database.getSetting(key(projectId, chapterId));
    return raw == null
        ? null
        : RoleReviewSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _write(RoleReviewSession session) async {
    final raw = jsonEncode(session.toJson());
    await database.setSetting(key(session.projectId, session.chapterId), raw);
    await database.setSetting(historyKey(session.id), raw);
  }

  Future<void> claim(RoleReviewSession session) => database.transaction(
    () async {
      final current = await load(session.projectId, session.chapterId);
      if (current?.status == 'running' &&
          current!.leaseUntil > DateTime.now().millisecondsSinceEpoch) {
        throw StateError('A local review is already running for this chapter.');
      }
      session.leaseUntil = DateTime.now().millisecondsSinceEpoch + 120000;
      await _write(session);
    },
  );
  Future<void> save(RoleReviewSession session) =>
      database.transaction(() async {
        final current = await load(session.projectId, session.chapterId);
        if (current?.id != session.id || current?.owner != session.owner) {
          throw StateError('Local review ownership changed.');
        }
        session.leaseUntil = session.status == 'running'
            ? DateTime.now().millisecondsSinceEpoch + 120000
            : 0;
        await _write(session);
      });
  Future<void> renew(
    String projectId,
    String chapterId,
    String id,
    String owner,
  ) => database.transaction(() async {
    final current = await load(projectId, chapterId);
    if (current?.id != id ||
        current?.owner != owner ||
        current?.status != 'running') {
      return;
    }
    current!.leaseUntil = DateTime.now().millisecondsSinceEpoch + 120000;
    await _write(current);
  });
  Stream<RoleReviewSession?> watch(String projectId, String chapterId) =>
      (database.select(database.appSettings)
            ..where((t) => t.key.equals(key(projectId, chapterId))))
          .watchSingleOrNull()
          .map(
            (r) => r == null
                ? null
                : RoleReviewSession.fromJson(
                    jsonDecode(r.value) as Map<String, dynamic>,
                  ),
          );

  /// Only selected, persisted proposals can be applied. Everything is one transaction.
  Future<int> apply(
    String projectId,
    String chapterId,
    String sessionId,
    Set<String> selected,
  ) => database.transaction(() async {
    final session = await load(projectId, chapterId);
    if (session == null ||
        session.id != sessionId ||
        !session.canApply ||
        selected.isEmpty ||
        selected.any((key) => !session.proposals.any((p) => p.key == key))) {
      throw StateError('No applicable saved review selection.');
    }
    final skill = await _loadSkill();
    final state = await RoleReviewSnapshot.load(
      database,
      projectId,
      chapterId,
      skill,
    );
    if (session.skillDigest != skill.digest ||
        session.signature != state.signature) {
      throw StateError(
        'Novel text, identities, labels, voices or skill changed. Start a fresh review.',
      );
    }
    final proposals = session.proposals
        .where((p) => selected.contains(p.key))
        .toList();
    final validation = RoleReviewSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );
    validation.proposals.clear();
    validation.journal.clear();
    validation.status = 'running';
    RoleReviewTools(state).dispatch(validation, [
      for (final p in proposals)
        {'action': p.action, 'key': p.key, ...p.data}..remove('affectedIds'),
    ]);
    final newIds = <String, String>{};
    final characters = CharacterRepository(database);
    var changed = 0;
    for (final p in proposals.where((p) => p.action == 'propose_character')) {
      newIds['new:${p.key}'] = await characters.saveCharacter(
        projectId: projectId,
        name: p.data['name'] as String,
        aliases: (p.data['aliases'] as List).cast<String>(),
        description: p.data['description'] as String,
        identityKind: CharacterIdentityKind.values.byName(
          p.data['identityKind'] as String,
        ),
      );
      changed++;
    }
    for (final p in proposals.where((p) => p.action == 'propose_merge')) {
      changed += await RoleReviewMerge.apply(
        database,
        state,
        p.data['fromId'] as String,
        p.data['intoId'] as String,
      );
      changed++;
    }
    final latest = await characters.load(projectId);
    final patches = <SegmentAnnotation>[];
    for (final p in proposals.where((p) => p.action == 'propose_patch')) {
      final id = p.data['segmentId'] as String;
      final row = state.requireSegment(id), before = latest.annotations[id];
      final ref = p.data['characterRef'] as String?;
      final characterId = ref == null ? null : (newIds[ref] ?? ref);
      if (characterId != null &&
          !latest.characters.any((c) => c.id == characterId)) {
        throw StateError(
          'A selected patch needs its proposed character or references a merged identity.',
        );
      }
      final kind = NovelSegmentKind.values.byName(p.data['kind'] as String);
      patches.add(
        SegmentAnnotation(
          segmentId: id,
          projectId: projectId,
          textRevision: novelTextRevision(row.segmentText),
          characterId: characterId,
          kind: kind,
          voiceAssetId: before?.voiceAssetId,
          instruction: before?.instruction,
          reviewState:
              characterId == null &&
                  [
                    NovelSegmentKind.dialogue,
                    NovelSegmentKind.thought,
                  ].contains(kind)
              ? NovelReviewState.conflict
              : NovelReviewState.inferred,
          reason: p.reason,
        ),
      );
    }
    changed += await AnnotationRepository(
      database,
    ).apply(projectId, patches, fromAi: true);
    session.status = 'applied';
    session.appliedKeys.addAll(selected);
    session.journal.add({
      'action': 'accepted_selection',
      'result': {
        'keys': selected.toList(),
        'newCharacterIds': newIds,
        'changes': changed,
      },
    });
    await _write(session);
    return changed;
  });
}
