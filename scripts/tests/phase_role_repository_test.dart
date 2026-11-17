import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_role_repository.dart';
import 'package:neiroha/data/services/novel/role_skill_profiles_repository.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'support/role_review_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  late RoleReviewFixture f;
  late RoleSkillProfilesRepository skills;
  late PhaseRoleRepository repo;
  late TextRolePlan plan;
  setUp(() async {
    f = RoleReviewFixture();
    await f.init();
    skills = RoleSkillProfilesRepository(
      f.database,
      loadBuiltin: loadTestRoleSkill,
    );
    repo = PhaseRoleRepository(f.database, skills);
    final now = DateTime.now();
    await f.database.insertPhaseTtsProject(
      db.PhaseTtsProjectsCompanion(
        id: const Value('phase'),
        name: const Value('Long text'),
        bankId: const Value('bank'),
        scriptText: const Value('你好。\n再见。'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await f.database.insertPhaseTtsSegment(
      const db.PhaseTtsSegmentsCompanion(
        id: Value('old'),
        projectId: Value('phase'),
        orderIndex: Value(0),
        segmentText: Value('旧分段'),
        audioPath: Value('/retained/old.wav'),
      ),
    );
    plan = TextRolePlan(
      text: '你好。\n再见。',
      skillDigest: (await skills.loadSkill()).digest,
      calls: 3,
      characters: const [
        StoryCharacter(id: 'speaker', projectId: 'temporary', name: '林舟'),
      ],
      units: const [
        TextRoleUnit(
          text: '你好。\n',
          start: 0,
          end: 4,
          kind: NovelSegmentKind.dialogue,
          characterId: 'speaker',
          review: NovelReviewState.inferred,
          reason: '发言',
        ),
        TextRoleUnit(
          text: '再见。',
          start: 4,
          end: 7,
          kind: NovelSegmentKind.narrator,
          review: NovelReviewState.inferred,
          reason: '旁白',
        ),
      ],
    );
  });
  tearDown(() => f.close());
  test(
    'selected voices and role labels apply atomically while the script stays exact',
    () async {
      final signature = await repo.signature('phase');
      await repo.apply(
        projectId: 'phase',
        expectedSignature: signature,
        plan: plan,
        voices: {'speaker': 'voice-a'},
      );
      final rows = await f.database.getPhaseTtsSegments('phase');
      expect(rows.map((s) => s.segmentText).join(), plan.text);
      expect(rows.first.speakerLabel, '林舟');
      expect(rows.first.voiceAssetId, 'voice-a');
      expect(rows.last.voiceAssetId, isNull);
      expect(
        (await f.database.getPhaseTtsProjectById('phase'))!.scriptText,
        plan.text,
      );
      expect(
        await f.database.getSetting('phase.roleAnalysis.phase'),
        contains('inferred'),
      );
    },
  );
  test('foreign voices fail without deleting original segments', () async {
    final signature = await repo.signature('phase');
    await expectLater(
      repo.apply(
        projectId: 'phase',
        expectedSignature: signature,
        plan: plan,
        voices: {'speaker': 'foreign-voice'},
      ),
      throwsArgumentError,
    );
    expect(
      (await f.database.getPhaseTtsSegments('phase')).single.audioPath,
      '/retained/old.wav',
    );
  });
  test(
    'changed stage prompts invalidate saved analysis before any writes',
    () async {
      final signature = await repo.signature('phase');
      await skills.save(
        const RoleSkillConfiguration(
          profiles: [
            RoleSkillProfile(
              id: 'default',
              name: 'Default',
              prompts: {'executor': 'Changed'},
            ),
          ],
        ),
      );
      await expectLater(
        repo.apply(
          projectId: 'phase',
          expectedSignature: signature,
          plan: plan,
          voices: {},
        ),
        throwsStateError,
      );
      expect((await f.database.getPhaseTtsSegments('phase')).single.id, 'old');
    },
  );
  test(
    'timeline clips block replacement instead of silently being discarded',
    () async {
      final signature = await repo.signature('phase');
      await f.database
          .into(f.database.timelineClips)
          .insert(
            const db.TimelineClipsCompanion(
              id: Value('clip'),
              projectId: Value('phase'),
              projectType: Value('phase'),
              audioPath: Value('/clip.wav'),
            ),
          );
      await expectLater(
        repo.apply(
          projectId: 'phase',
          expectedSignature: signature,
          plan: plan,
          voices: {},
        ),
        throwsStateError,
      );
      expect(
        (await f.database.select(f.database.timelineClips).get()),
        hasLength(1),
      );
      expect((await f.database.getPhaseTtsSegments('phase')).single.id, 'old');
    },
  );
}
