import 'dart:convert';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'role_skill_repository.dart';

/// Per-node overrides layer over immutable, compiled-in defaults.
class RoleSkillProfilesRepository {
  RoleSkillProfilesRepository(this.database, {RoleSkillLoader? loadBuiltin})
    : _loadBuiltin = loadBuiltin ?? RoleSkillRepository().load;
  final AppDatabase database;
  final RoleSkillLoader _loadBuiltin;
  static const key = 'ai.roleSkillProfiles.v1';
  RoleSkillConfiguration _decode(String? raw) => raw == null
      ? const RoleSkillConfiguration()
      : RoleSkillConfiguration.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
  Future<RoleSkillConfiguration> load() async =>
      _decode(await database.getSetting(key));
  Stream<RoleSkillConfiguration> watch() =>
      (database.select(database.appSettings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((r) => _decode(r?.value));
  Future<NovelRoleSkill> builtin() => _loadBuiltin();
  Future<NovelRoleSkill> loadSkill() async {
    final p = (await load()).active;
    return (await builtin()).customize(p.id, p.prompts);
  }

  Future<void> save(RoleSkillConfiguration value) async {
    value.validate();
    final builtin = await _loadBuiltin();
    final providers = await database.getAllProviders();
    for (final p in value.profiles) {
      builtin.customize(p.id, p.prompts);
      if (p.providerId != null && !providers.any((c) => c.id == p.providerId)) {
        throw StateError('Role configuration connection was deleted.');
      }
    }
    await database.setSetting(key, jsonEncode(value.toJson()));
  }
}
