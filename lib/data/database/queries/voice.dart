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
    return _deleteVoiceAssetRows(id);
  });

  Future<int> _deleteVoiceAssetRows(String id) async {
    // Drop FK references before deleting the asset itself, otherwise SQLite
    // raises a foreign-key constraint and the asset stays in the table. Also
    // clear nullable project references so editors do not keep stale ids.
    await (update(phaseTtsSegments)..where((t) => t.voiceAssetId.equals(id)))
        .write(const PhaseTtsSegmentsCompanion(voiceAssetId: Value(null)));
    await (update(novelProjects)
          ..where((t) => t.narratorVoiceAssetId.equals(id)))
        .write(const NovelProjectsCompanion(narratorVoiceAssetId: Value(null)));
    await (update(novelProjects)
          ..where((t) => t.dialogueVoiceAssetId.equals(id)))
        .write(const NovelProjectsCompanion(dialogueVoiceAssetId: Value(null)));
    await (update(dialogTtsLines)..where((t) => t.voiceAssetId.equals(id)))
        .write(const DialogTtsLinesCompanion(voiceAssetId: Value(null)));
    await (update(subtitleCues)..where((t) => t.voiceAssetId.equals(id))).write(
      const SubtitleCuesCompanion(voiceAssetId: Value(null)),
    );
    await (delete(
      voiceBankMembers,
    )..where((t) => t.voiceAssetId.equals(id))).go();
    await (delete(ttsJobs)..where((t) => t.voiceAssetId.equals(id))).go();
    await (delete(
      quickTtsHistories,
    )..where((t) => t.voiceAssetId.equals(id))).go();
    return (delete(voiceAssets)..where((t) => t.id.equals(id))).go();
  }

  // --- VoiceBank CRUD ---

  Stream<List<VoiceBank>> watchAllBanks() => select(voiceBanks).watch();

  Future<List<VoiceBank>> getAllBanks() => select(voiceBanks).get();

  Future<int> insertBank(VoiceBanksCompanion bank) =>
      into(voiceBanks).insert(bank);

  Future<bool> updateBank(VoiceBank bank) => update(voiceBanks).replace(bank);

  Future<int> deleteBank(String id) => transaction(() async {
    final usage = await _voiceBankProjectUsage(id);
    if (_voiceBankProjectUsageCount(usage) > 0) {
      throw StateError(
        'Voice bank is used by ${_formatVoiceBankProjectUsage(usage)}',
      );
    }
    final members = await getBankMembers(id);
    await (delete(voiceBankMembers)..where((t) => t.bankId.equals(id))).go();
    final removed = await (delete(
      voiceBanks,
    )..where((t) => t.id.equals(id))).go();
    for (final member in members) {
      if (await _voiceAssetMembershipCount(member.voiceAssetId) == 0) {
        await _deleteVoiceAssetRows(member.voiceAssetId);
      }
    }
    return removed;
  });

  Future<({int phase, int novel, int dialog, int video})>
  _voiceBankProjectUsage(String bankId) async {
    final phase = await (select(
      phaseTtsProjects,
    )..where((t) => t.bankId.equals(bankId))).get();
    final novel = await (select(
      novelProjects,
    )..where((t) => t.bankId.equals(bankId))).get();
    final dialog = await (select(
      dialogTtsProjects,
    )..where((t) => t.bankId.equals(bankId))).get();
    final video = await (select(
      videoDubProjects,
    )..where((t) => t.bankId.equals(bankId))).get();
    return (
      phase: phase.length,
      novel: novel.length,
      dialog: dialog.length,
      video: video.length,
    );
  }

  int _voiceBankProjectUsageCount(
    ({int phase, int novel, int dialog, int video}) usage,
  ) {
    return usage.phase + usage.novel + usage.dialog + usage.video;
  }

  String _formatVoiceBankProjectUsage(
    ({int phase, int novel, int dialog, int video}) usage,
  ) {
    final parts = <String>[];
    if (usage.phase > 0) parts.add('${usage.phase} Phase project(s)');
    if (usage.novel > 0) parts.add('${usage.novel} Novel project(s)');
    if (usage.dialog > 0) parts.add('${usage.dialog} Dialog project(s)');
    if (usage.video > 0) parts.add('${usage.video} Video Dub project(s)');
    return parts.join(', ');
  }

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

  Future<int> addMemberToBank(VoiceBankMembersCompanion member) async {
    if (member.bankId.present && member.voiceAssetId.present) {
      final existing =
          await (select(voiceBankMembers)..where(
                (t) =>
                    t.bankId.equals(member.bankId.value) &
                    t.voiceAssetId.equals(member.voiceAssetId.value),
              ))
              .getSingleOrNull();
      if (existing != null) return 0;
    }
    return into(voiceBankMembers).insert(member);
  }

  Future<int> removeMemberFromBank(
    String memberId, {
    bool deleteOrphanAsset = false,
  }) => transaction(() async {
    final member = await (select(
      voiceBankMembers,
    )..where((t) => t.id.equals(memberId))).getSingleOrNull();
    if (member == null) return 0;
    final removed = await (delete(
      voiceBankMembers,
    )..where((t) => t.id.equals(memberId))).go();
    if (deleteOrphanAsset &&
        removed > 0 &&
        await _voiceAssetMembershipCount(member.voiceAssetId) == 0) {
      await _deleteVoiceAssetRows(member.voiceAssetId);
    }
    return removed;
  });

  Future<int> removeMemberByAssetAndBank(
    String bankId,
    String voiceAssetId, {
    bool deleteOrphanAsset = false,
  }) => transaction(() async {
    final removed =
        await (delete(voiceBankMembers)..where(
              (t) =>
                  t.bankId.equals(bankId) & t.voiceAssetId.equals(voiceAssetId),
            ))
            .go();
    if (deleteOrphanAsset &&
        removed > 0 &&
        await _voiceAssetMembershipCount(voiceAssetId) == 0) {
      await _deleteVoiceAssetRows(voiceAssetId);
    }
    return removed;
  });

  Future<int> _voiceAssetMembershipCount(String voiceAssetId) async {
    final rows = await (select(
      voiceBankMembers,
    )..where((t) => t.voiceAssetId.equals(voiceAssetId))).get();
    return rows.length;
  }

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
