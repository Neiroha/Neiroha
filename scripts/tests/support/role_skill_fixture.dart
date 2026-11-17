import 'dart:io';
import 'package:neiroha/data/services/novel/role_skill_repository.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';

Future<NovelRoleSkill> loadTestRoleSkill() async => NovelRoleSkill.parse(
  await File(
    Platform.environment['NEIROHA_ROLE_SKILL_FILE'] ??
        RoleSkillRepository.assetPath,
  ).readAsString(),
);
