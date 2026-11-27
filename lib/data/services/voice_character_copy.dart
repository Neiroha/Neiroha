import 'package:drift/drift.dart' show Value;
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:uuid/uuid.dart';

/// Copies a character, its processing chain and (with [bankId]) its bank
/// membership. Returns the new character's id.
Future<String> duplicateVoiceCharacter(
  db.AppDatabase database,
  db.VoiceAsset asset, {
  String? bankId,
}) async {
  final newId = const Uuid().v4();
  await database.transaction(() async {
    await database.insertVoiceAsset(
      db.VoiceAssetsCompanion(
        id: Value(newId),
        name: Value('${asset.name} (copy)'),
        description: Value(asset.description),
        providerId: Value(asset.providerId),
        modelBindingId: Value(asset.modelBindingId),
        modelName: Value(asset.modelName),
        taskMode: Value(asset.taskMode),
        refAudioPath: Value(asset.refAudioPath),
        refAudioTrimStart: Value(asset.refAudioTrimStart),
        refAudioTrimEnd: Value(asset.refAudioTrimEnd),
        promptText: Value(asset.promptText),
        promptLang: Value(asset.promptLang),
        voiceInstruction: Value(asset.voiceInstruction),
        presetVoiceName: Value(asset.presetVoiceName),
        avatarPath: Value(asset.avatarPath),
        speed: Value(asset.speed),
        enabled: Value(asset.enabled),
        loudnessOffsetDb: Value(asset.loudnessOffsetDb),
        seed: Value(asset.seed),
      ),
    );
    for (final slot in db.CharacterSettingSlot.values) {
      final json = await database.getVoiceAssetSetting(asset.id, slot);
      if (json != null) await database.setVoiceAssetSetting(newId, slot, json);
    }
    if (bankId != null) {
      await database.addMemberToBank(
        db.VoiceBankMembersCompanion(
          id: Value(const Uuid().v4()),
          bankId: Value(bankId),
          voiceAssetId: Value(newId),
        ),
      );
    }
  });
  return newId;
}
