import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/novel/role_skill_profiles_repository.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'support/novel_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  late AppDatabase database;
  late RoleSkillProfilesRepository repo;
  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    repo = RoleSkillProfilesRepository(
      database,
      loadBuiltin: loadTestRoleSkill,
    );
  });
  tearDown(() => database.close());
  test(
    'profiles persist per-stage overrides without changing compiled defaults',
    () async {
      final source = File(
        'assets/skills/novel-role-assign/SKILL.md',
      ).readAsStringSync();
      final builtin = await repo.builtin();
      expect((await repo.loadSkill()).digest, builtin.digest);
      await repo.save(
        const RoleSkillConfiguration(
          activeId: 'custom',
          profiles: [
            RoleSkillProfile(id: 'default', name: 'Default'),
            RoleSkillProfile(
              id: 'custom',
              name: '广播剧',
              providerId: 'test-provider',
              prompts: {'executor': '自定义分角规则', 'replanner': '自定义重规划规则'},
            ),
          ],
        ),
      );
      final reopened = RoleSkillProfilesRepository(
        database,
        loadBuiltin: loadTestRoleSkill,
      );
      final active = await reopened.loadSkill();
      expect(active.prompt('executor'), '自定义分角规则');
      expect(active.prompt('replanner'), '自定义重规划规则');
      expect(active.prompt('planner'), builtin.prompt('planner'));
      expect(active.digest, isNot(builtin.digest));
      expect((await reopened.load()).active.model, 'gpt-6-luna');
      expect(
        File('assets/skills/novel-role-assign/SKILL.md').readAsStringSync(),
        source,
      );
      await repo.save(const RoleSkillConfiguration());
      expect((await repo.loadSkill()).digest, builtin.digest);
    },
  );
  test(
    'invalid nodes, empty prompts, duplicate profiles and missing providers do not overwrite settings',
    () async {
      await repo.save(const RoleSkillConfiguration());
      final before = await database.getSetting(RoleSkillProfilesRepository.key);
      for (final profile in [
        const RoleSkillProfile(
          id: 'default',
          name: 'bad',
          prompts: {'execute_shell': 'run'},
        ),
        const RoleSkillProfile(
          id: 'default',
          name: 'bad',
          prompts: {'planner': ''},
        ),
        const RoleSkillProfile(
          id: 'default',
          name: 'bad',
          providerId: 'deleted',
        ),
      ]) {
        await expectLater(
          repo.save(RoleSkillConfiguration(profiles: [profile])),
          throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
        );
        expect(
          await database.getSetting(RoleSkillProfilesRepository.key),
          before,
        );
      }
      await expectLater(
        repo.save(
          const RoleSkillConfiguration(
            profiles: [
              RoleSkillProfile(id: 'default', name: 'a'),
              RoleSkillProfile(id: 'default', name: 'b'),
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'legacy skills fall back to planner with LF and CRLF line endings',
    () async {
      final source = File(
        'assets/skills/novel-role-assign/SKILL.md',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final section = RegExp(r'\n## replanner\n[\s\S]*?(?=\n## |$)');
      expect(section.hasMatch(source), isTrue);
      final legacySource = source.replaceFirst(section, '\n');
      for (final document in [
        legacySource,
        legacySource.replaceAll('\n', '\r\n'),
      ]) {
        final legacy = NovelRoleSkill.parse(document);
        expect(legacy.prompt('replanner'), legacy.prompt('planner'));
      }
    },
  );
}
