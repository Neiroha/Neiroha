import 'dart:convert';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';

/// Additive, versioned role settings. No changes to existing character IDs or
/// binding primary keys are needed for per-kind overrides.
class RolePreferences {
  const RolePreferences(this.database);
  final db.AppDatabase database;
  String key(String projectId) => 'novel.roles.preferences.$projectId';

  Future<Map<String, dynamic>> load(String projectId) async {
    final raw = await database.getSetting(key(projectId));
    if (raw == null) return {'version': 1, 'identities': {}, 'styles': []};
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['version'] != 1) {
      throw const FormatException('Unknown role settings');
    }
    return value;
  }

  Future<void> setIdentity(
    String projectId,
    String id,
    CharacterIdentityKind kind,
  ) => database.transaction(() async {
    await _validate(projectId, id);
    final data = await load(projectId);
    (data['identities'] as Map)[id] = kind.name;
    await database.setSetting(key(projectId), jsonEncode(data));
  });

  Future<void> setStyle({
    required String projectId,
    required String characterId,
    required NovelSegmentKind kind,
    String chapterId = '',
    String? voiceAssetId,
    String? instruction,
  }) => database.transaction(() async {
    await _validate(projectId, characterId, chapterId: chapterId);
    if (voiceAssetId != null) {
      final project = (await database.getNovelProjectById(projectId))!;
      if (!(await database.getBankMembers(
        project.bankId,
      )).any((m) => m.voiceAssetId == voiceAssetId)) {
        throw ArgumentError('Voice is not in this novel’s bank.');
      }
    }
    final data = await load(projectId);
    final styles = data['styles'] as List;
    styles.removeWhere(
      (s) =>
          s['characterId'] == characterId &&
          s['chapterId'] == chapterId &&
          s['kind'] == kind.name,
    );
    if (voiceAssetId != null || instruction?.trim().isNotEmpty == true) {
      styles.add({
        'characterId': characterId,
        'chapterId': chapterId,
        'kind': kind.name,
        'voiceAssetId': voiceAssetId,
        'instruction': instruction?.trim().isNotEmpty == true
            ? instruction!.trim()
            : null,
      });
    }
    await database.setSetting(key(projectId), jsonEncode(data));
  });

  Future<void> _validate(
    String projectId,
    String id, {
    String chapterId = '',
  }) async {
    final characters = await database.select(database.novelCharacters).get();
    if (!characters.any((c) => c.id == id && c.projectId == projectId)) {
      throw ArgumentError('Unknown character in this novel.');
    }
    if (chapterId.isNotEmpty &&
        !(await database.getNovelChapters(
          projectId,
        )).any((c) => c.id == chapterId)) {
      throw ArgumentError('Chapter belongs to another novel.');
    }
  }

  static List<CharacterVoiceBinding> styles(Map<String, dynamic> data) => [
    for (final s in data['styles'] as List)
      CharacterVoiceBinding(
        characterId: s['characterId'] as String,
        // A style-only entry inherits the voice from the next matching binding.
        voiceAssetId: s['voiceAssetId'] as String? ?? '',
        chapterId: s['chapterId'] as String,
        kind: NovelSegmentKind.values.byName(s['kind'] as String),
        instruction: s['instruction'] as String?,
      ),
  ];
}
