part of '../app_database.dart';

extension AppDatabaseVoiceQueries on AppDatabase {
  // --- VoiceAsset / Character CRUD ---

  Future<List<VoiceAsset>> getAllVoiceAssets() => select(voiceAssets).get();

  Stream<List<VoiceAsset>> watchAllVoiceAssets() => select(voiceAssets).watch();

  Future<VoiceAsset?> getVoiceAssetByName(String name) => (select(
    voiceAssets,
  )..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<VoiceAsset?> getVoiceAssetById(String id) =>
      (select(voiceAssets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertVoiceAsset(VoiceAssetsCompanion asset) =>
      into(voiceAssets).insert(asset);

  Future<bool> updateVoiceAsset(VoiceAsset asset) =>
      update(voiceAssets).replace(asset);

  Future<int> deleteVoiceAsset(String id) => transaction(() async {
    // Drop FK references before deleting the asset itself, otherwise
    // SQLite raises a foreign-key constraint and the asset stays in the
    // table — leading to "name already exists" on the next create attempt.
    await (delete(
      voiceBankMembers,
    )..where((t) => t.voiceAssetId.equals(id))).go();
    await (delete(ttsJobs)..where((t) => t.voiceAssetId.equals(id))).go();
    await (delete(
      quickTtsHistories,
    )..where((t) => t.voiceAssetId.equals(id))).go();
    return (delete(voiceAssets)..where((t) => t.id.equals(id))).go();
  });

  // --- VoiceBank CRUD ---

  Stream<List<VoiceBank>> watchAllBanks() => select(voiceBanks).watch();

  Future<List<VoiceBank>> getAllBanks() => select(voiceBanks).get();

  Future<int> insertBank(VoiceBanksCompanion bank) =>
      into(voiceBanks).insert(bank);

  Future<bool> updateBank(VoiceBank bank) => update(voiceBanks).replace(bank);

  Future<int> deleteBank(String id) => transaction(() async {
    // Remove members first
    await (delete(voiceBankMembers)..where((t) => t.bankId.equals(id))).go();
    return (delete(voiceBanks)..where((t) => t.id.equals(id))).go();
  });

  /// Set one bank as active, deactivating all others.
  Future<void> setActiveBank(String bankId) => transaction(() async {
    await (update(voiceBanks)..where((t) => t.isActive.equals(true))).write(
      const VoiceBanksCompanion(isActive: Value(false)),
    );
    await (update(voiceBanks)..where((t) => t.id.equals(bankId))).write(
      const VoiceBanksCompanion(isActive: Value(true)),
    );
  });

  Future<void> deactivateAllBanks() async {
    await (update(voiceBanks)..where((t) => t.isActive.equals(true))).write(
      const VoiceBanksCompanion(isActive: Value(false)),
    );
  }

  Stream<VoiceBank?> watchActiveBank() => (select(
    voiceBanks,
  )..where((t) => t.isActive.equals(true))).watchSingleOrNull();

  /// Get all activated banks (for API server — multiple banks can be active).
  Future<List<VoiceBank>> getActiveBanks() =>
      (select(voiceBanks)..where((t) => t.isActive.equals(true))).get();

  Stream<List<VoiceBank>> watchActiveBanks() =>
      (select(voiceBanks)..where((t) => t.isActive.equals(true))).watch();

  /// Toggle a single bank's active state without affecting others.
  Future<void> toggleBankActive(String bankId, bool active) async {
    await (update(voiceBanks)..where((t) => t.id.equals(bankId))).write(
      VoiceBanksCompanion(isActive: Value(active)),
    );
  }

  // --- VoiceBankMember CRUD ---

  Stream<List<VoiceBankMember>> watchBankMembers(String bankId) =>
      (select(voiceBankMembers)..where((t) => t.bankId.equals(bankId))).watch();

  Future<List<VoiceBankMember>> getBankMembers(String bankId) =>
      (select(voiceBankMembers)..where((t) => t.bankId.equals(bankId))).get();

  Future<int> addMemberToBank(VoiceBankMembersCompanion member) =>
      into(voiceBankMembers).insert(member);

  Future<int> removeMemberFromBank(String memberId) =>
      (delete(voiceBankMembers)..where((t) => t.id.equals(memberId))).go();

  Future<void> removeMemberByAssetAndBank(String bankId, String voiceAssetId) =>
      (delete(voiceBankMembers)..where(
            (t) =>
                t.bankId.equals(bankId) & t.voiceAssetId.equals(voiceAssetId),
          ))
          .go();

  /// Duplicate a bank with all its members.
  Future<VoiceBank> duplicateBank(String bankId, String newName) => transaction(
    () async {
      final original = await (select(
        voiceBanks,
      )..where((t) => t.id.equals(bankId))).getSingle();
      final newId = const Uuid().v4();
      await into(voiceBanks).insert(
        VoiceBanksCompanion(
          id: Value(newId),
          name: Value(newName),
          description: Value(original.description),
          isActive: const Value(false),
          createdAt: Value(DateTime.now()),
        ),
      );
      final members = await getBankMembers(bankId);
      for (final m in members) {
        await into(voiceBankMembers).insert(
          VoiceBankMembersCompanion(
            id: Value(const Uuid().v4()),
            bankId: Value(newId),
            voiceAssetId: Value(m.voiceAssetId),
          ),
        );
      }
      return (select(voiceBanks)..where((t) => t.id.equals(newId))).getSingle();
    },
  );
}
