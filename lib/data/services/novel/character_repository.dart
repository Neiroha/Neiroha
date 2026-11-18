import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:uuid/uuid.dart';

import 'role_mapping.dart';
import 'role_preferences.dart';

class CharacterRepository {
  const CharacterRepository(this.database);
  final db.AppDatabase database;

  Stream<NovelRoleSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT 1',
        readsFrom: {
          database.novelCharacters,
          database.novelAnnotations,
          database.novelVoiceBindings,
          database.appSettings,
        },
      )
      .watch()
      .asyncMap((_) => load(projectId));

  Future<NovelRoleSnapshot> load(String projectId) => database.transaction(
    () async {
      final characters = await (database.select(
        database.novelCharacters,
      )..where((t) => t.projectId.equals(projectId))).get();
      final annotations = await (database.select(
        database.novelAnnotations,
      )..where((t) => t.projectId.equals(projectId))).get();
      final bindings = await (database.select(
        database.novelVoiceBindings,
      )..where((t) => t.characterId.isIn(characters.map((c) => c.id)))).get();
      final preferences = await RolePreferences(database).load(projectId);
      final identities = preferences['identities'] as Map;
      return NovelRoleSnapshot(
        characters: [
          for (final c in characters)
            storyCharacterFromRow(
              c,
              identityKind: CharacterIdentityKind.values.byName(
                identities[c.id] as String? ?? 'named',
              ),
            ),
        ],
        annotations: {
          for (final row in annotations) row.segmentId: annotationFromRow(row),
        },
        bindings: [
          ...bindings.map(bindingFromRow),
          ...RolePreferences.styles(
            preferences,
          ).where((s) => characters.any((c) => c.id == s.characterId)),
        ],
      );
    },
  );

  Future<String> saveCharacter({
    required String projectId,
    String? id,
    required String name,
    List<String> aliases = const [],
    String description = '',
    int? color,
    CharacterIdentityKind? identityKind,
  }) => database.transaction(() async {
    if (name.trim().isEmpty) throw ArgumentError('Character name is empty.');
    if (await database.getNovelProjectById(projectId) == null) {
      throw StateError('Novel project was deleted.');
    }
    if (id != null) await _requireCharacter(projectId, id);
    final characterId = id ?? const Uuid().v4();
    const palette = [
      0xFF7E9CD8,
      0xFFE6A375,
      0xFF98BB6C,
      0xFFD27E99,
      0xFF7FB4CA,
      0xFFC0A36E,
    ];
    final existing = await (database.select(
      database.novelCharacters,
    )..where((t) => t.projectId.equals(projectId))).get();
    final resolvedColor = color ?? palette[existing.length % palette.length];
    await database
        .into(database.novelCharacters)
        .insertOnConflictUpdate(
          db.NovelCharactersCompanion.insert(
            id: characterId,
            projectId: projectId,
            name: name.trim(),
            aliasesJson: Value(
              jsonEncode(
                aliases
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList(),
              ),
            ),
            description: Value(description.trim()),
            color: Value(resolvedColor),
          ),
        );
    if (identityKind != null) {
      await RolePreferences(
        database,
      ).setIdentity(projectId, characterId, identityKind);
    }
    return characterId;
  });

  Future<void> bindVoice({
    required String projectId,
    required String characterId,
    required String? voiceAssetId,
    String chapterId = '',
    String? instruction,
  }) => database.transaction(() async {
    await _requireCharacter(projectId, characterId);
    if (chapterId.isNotEmpty) {
      final chapter = await (database.select(
        database.novelChapters,
      )..where((t) => t.id.equals(chapterId))).getSingleOrNull();
      if (chapter?.projectId != projectId) {
        throw ArgumentError('Chapter belongs to another novel.');
      }
    }
    final query = database.delete(database.novelVoiceBindings)
      ..where(
        (t) =>
            t.characterId.equals(characterId) & t.chapterId.equals(chapterId),
      );
    if (voiceAssetId == null) {
      await query.go();
      return;
    }
    final project = (await database.getNovelProjectById(projectId))!;
    final members = await database.getBankMembers(project.bankId);
    if (!members.any((m) => m.voiceAssetId == voiceAssetId) ||
        await database.getVoiceAssetById(voiceAssetId) == null) {
      throw ArgumentError('Voice is not in this novel’s voice bank.');
    }
    await database
        .into(database.novelVoiceBindings)
        .insertOnConflictUpdate(
          db.NovelVoiceBindingsCompanion.insert(
            characterId: characterId,
            chapterId: Value(chapterId),
            voiceAssetId: voiceAssetId,
            instruction: Value(
              instruction?.trim().isEmpty == true ? null : instruction?.trim(),
            ),
          ),
        );
  });

  /// Explicit manual merge. Locked sentences keep their lock and identity
  /// deliberately moves to the chosen character; original aliases are retained.
  Future<void> merge(String projectId, String fromId, String intoId) =>
      database.transaction(() async {
        if (fromId == intoId) return;
        final from = await _requireCharacter(projectId, fromId);
        final target = await _requireCharacter(projectId, intoId);
        final aliases = <String>{
          target.name,
          from.name,
          ...(jsonDecode(target.aliasesJson) as List).cast<String>(),
          ...(jsonDecode(from.aliasesJson) as List).cast<String>(),
        }..remove(target.name);
        await (database.update(
          database.novelCharacters,
        )..where((t) => t.id.equals(intoId))).write(
          db.NovelCharactersCompanion(
            aliasesJson: Value(jsonEncode(aliases.toList())),
          ),
        );
        await (database.update(database.novelAnnotations)..where(
              (t) =>
                  t.projectId.equals(projectId) & t.characterId.equals(fromId),
            ))
            .write(
              db.NovelAnnotationsCompanion(
                characterId: Value(intoId),
                changeId: Value(const Uuid().v4()),
              ),
            );
        await (database.delete(
          database.novelVoiceBindings,
        )..where((t) => t.characterId.equals(fromId))).go();
        await (database.delete(
          database.novelCharacters,
        )..where((t) => t.id.equals(fromId))).go();
      });

  Future<db.NovelCharacter> _requireCharacter(
    String projectId,
    String id,
  ) async {
    final row = await (database.select(
      database.novelCharacters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.projectId != projectId) {
      throw ArgumentError('Character belongs to another novel.');
    }
    return row;
  }
}
