import 'package:flutter/services.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';

typedef RoleSkillLoader = Future<NovelRoleSkill> Function();

/// Loads the bundled skill, with injectable text loading for offline tooling.
class RoleSkillRepository {
  RoleSkillRepository({Future<String> Function()? loadDocument})
    : _loadDocument = loadDocument ?? (() => rootBundle.loadString(assetPath));

  static const assetPath = 'assets/skills/novel-role-assign/SKILL.md';
  final Future<String> Function() _loadDocument;

  Future<NovelRoleSkill> load() async =>
      NovelRoleSkill.parse(await _loadDocument());
}
