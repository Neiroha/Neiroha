import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/novel/role_skill_repository.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';

void main() {
  final document = File(RoleSkillRepository.assetPath).readAsStringSync();
  test(
    'skill identity covers content and normalizes platform line endings',
    () {
      final skill = NovelRoleSkill.parse(document);
      expect(skill.digest, hasLength(64));
      expect(
        NovelRoleSkill.parse(
          document.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n'),
        ).digest,
        skill.digest,
      );
      final changed = NovelRoleSkill.parse(
        document.replaceFirst('Assign labels', 'Assign checked labels'),
      );
      expect(changed.version, skill.version);
      expect(changed.digest, isNot(skill.digest));
    },
  );
  test(
    'incomplete, duplicated and incompatible skills fail before inference',
    () {
      expect(
        () => NovelRoleSkill.parse(
          document.replaceFirst('## reviewer', '## unused'),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            NovelRoleSkill.parse('$document\n## planner\nDuplicated rules.\n'),
        throwsFormatException,
      );
      expect(
        () => NovelRoleSkill.parse(
          document.replaceFirst('neiroha-role-analysis-v1', 'another-runtime'),
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets('moved runtime resources and both skills are packaged', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final skill = await RoleSkillRepository().load();
      expect(skill.name, 'novel-role-assign');
      final icon = await rootBundle.loadString('assets/icon/neiroha_logo.svg');
      expect(icon, contains('<svg'));
      final catalog =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/model_catalog/model_capabilities.snapshot.json',
                ),
              )
              as Map;
      expect(catalog['models'], isNotEmpty);
      for (final name in ['neiroha-dubbing', 'novel-role-assign']) {
        expect(
          await rootBundle.loadString('assets/skills/$name/SKILL.md'),
          isNotEmpty,
        );
        expect(
          await rootBundle.loadString('assets/skills/$name/EVALUATION.md'),
          isNotEmpty,
        );
      }
    });
  });
}
