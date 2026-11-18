import 'novel_role_skill.dart';

class RoleSkillProfile {
  const RoleSkillProfile({
    required this.id,
    required this.name,
    this.model = 'gpt-6-luna',
    this.providerId,
    this.prompts = const {},
  });
  final String id, name, model;
  final String? providerId;
  final Map<String, String> prompts;
  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,50}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 100 ||
        model.trim().isEmpty ||
        model.length > 150 ||
        (providerId?.length ?? 0) > 100 ||
        prompts.length > NovelRoleSkill.stages.length ||
        prompts.entries.any(
          (e) =>
              !NovelRoleSkill.stages.contains(e.key) ||
              e.value.trim().isEmpty ||
              e.value.length > 16000,
        )) {
      throw const FormatException('Invalid role skill profile.');
    }
  }

  RoleSkillProfile copyWith({
    String? name,
    String? model,
    Map<String, String>? prompts,
  }) => RoleSkillProfile(
    id: id,
    name: name ?? this.name,
    model: model ?? this.model,
    providerId: providerId,
    prompts: prompts ?? this.prompts,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'model': model,
    'providerId': providerId,
    'prompts': prompts,
  };
  factory RoleSkillProfile.fromJson(Map<String, dynamic> j) {
    final p = RoleSkillProfile(
      id: j['id'] as String,
      name: j['name'] as String,
      model: j['model'] as String,
      providerId: j['providerId'] as String?,
      prompts: Map<String, String>.from(j['prompts'] as Map),
    );
    p.validate();
    return p;
  }
}

class RoleSkillConfiguration {
  const RoleSkillConfiguration({
    this.activeId = 'default',
    this.profiles = const [RoleSkillProfile(id: 'default', name: 'Default')],
  });
  final String activeId;
  final List<RoleSkillProfile> profiles;
  RoleSkillProfile get active => profiles.firstWhere((p) => p.id == activeId);
  void validate() {
    if (profiles.isEmpty ||
        profiles.length > 20 ||
        profiles.map((p) => p.id).toSet().length != profiles.length ||
        !profiles.any((p) => p.id == activeId) ||
        !profiles.any((p) => p.id == 'default')) {
      throw const FormatException('Invalid role skill configuration.');
    }
    for (final p in profiles) {
      p.validate();
    }
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'activeId': activeId,
    'profiles': profiles.map((p) => p.toJson()).toList(),
  };
  factory RoleSkillConfiguration.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unknown role settings version.');
    }
    final c = RoleSkillConfiguration(
      activeId: j['activeId'] as String,
      profiles: (j['profiles'] as List)
          .map(
            (p) =>
                RoleSkillProfile.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList(),
    );
    c.validate();
    return c;
  }
}
