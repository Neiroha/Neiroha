import 'role_models.dart';

/// Story identities are references to work-level IDs, never new aliases for 我/他.
class RoleSceneState {
  const RoleSceneState({
    this.firstPersonId,
    this.presentCharacterIds = const [],
    this.nestedNarratorIds = const [],
    this.messageChannels = const [],
    this.evidence = '',
  });
  final String? firstPersonId;
  final List<String> presentCharacterIds;
  final List<String> nestedNarratorIds;
  final List<String> messageChannels;
  final String evidence;
  static const channels = [
    'spoken',
    'thought',
    'chat',
    'system',
    'letter',
    'unknown',
  ];

  factory RoleSceneState.fromPlan(Object? raw, NovelRoleSnapshot roles) {
    if (raw == null) {
      return const RoleSceneState(); // Explicit unknown for legacy clients.
    }
    if (raw is! Map) throw const FormatException('Invalid scene state.');
    String? resolve(Object? name) {
      if (name == null) return null;
      if (name is! String) {
        throw const FormatException('Invalid scene identity.');
      }
      final matches = roles.characters.where(
        (c) => c.name == name || c.aliases.contains(name),
      );
      if (matches.length != 1) {
        throw const FormatException('Unknown or ambiguous scene identity.');
      }
      return matches.single.id;
    }

    List<String> identities(Object? names) {
      if (names is! List || names.length > 100) {
        throw const FormatException('Invalid scene cast.');
      }
      return names
          .map(
            (n) =>
                resolve(n) ??
                (throw const FormatException('Null scene identity.')),
          )
          .toSet()
          .toList();
    }

    final messageChannels = raw['messageChannels'];
    final evidence = raw['evidence'];
    if (messageChannels is! List ||
        messageChannels.any((c) => !channels.contains(c)) ||
        evidence is! String ||
        evidence.length > 1000) {
      throw const FormatException('Invalid scene evidence or channel.');
    }
    return RoleSceneState(
      firstPersonId: resolve(raw['firstPersonName']),
      presentCharacterIds: identities(raw['presentCharacterNames']),
      nestedNarratorIds: identities(raw['nestedNarratorNames']),
      messageChannels: messageChannels.cast<String>().toSet().toList(),
      evidence: evidence,
    );
  }
  Map<String, Object?> toJson() => {
    'firstPersonId': firstPersonId,
    'presentCharacterIds': presentCharacterIds,
    'nestedNarratorIds': nestedNarratorIds,
    'messageChannels': messageChannels,
    'evidence': evidence,
  };
  Map<String, Object?> forRoster(NovelRoleSnapshot roles) {
    final ids = roles.characters.map((c) => c.id).toSet();
    return {
      ...toJson(),
      'firstPersonId': ids.contains(firstPersonId) ? firstPersonId : null,
      'presentCharacterIds': presentCharacterIds.where(ids.contains).toList(),
      'nestedNarratorIds': nestedNarratorIds.where(ids.contains).toList(),
    };
  }

  factory RoleSceneState.fromJson(Map<String, dynamic> json) => RoleSceneState(
    firstPersonId: json['firstPersonId'] as String?,
    presentCharacterIds: (json['presentCharacterIds'] as List? ?? [])
        .cast<String>(),
    nestedNarratorIds: (json['nestedNarratorIds'] as List? ?? [])
        .cast<String>(),
    messageChannels: (json['messageChannels'] as List? ?? []).cast<String>(),
    evidence: json['evidence'] as String? ?? '',
  );
}
