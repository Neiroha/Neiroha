part of '../app_database.dart';

/// Which column of [VoiceAssetSettings] a per-character setting lives in.
enum CharacterSettingSlot { chain, live }

extension AppDatabaseAiQueries on AppDatabase {
  // --- Per-character settings ---

  Future<String?> getVoiceAssetSetting(
    String voiceAssetId,
    CharacterSettingSlot which,
  ) async {
    final row = await (select(
      voiceAssetSettings,
    )..where((t) => t.voiceAssetId.equals(voiceAssetId))).getSingleOrNull();
    return switch (which) {
      CharacterSettingSlot.chain => row?.chainJson,
      CharacterSettingSlot.live => row?.liveJson,
    };
  }

  Future<void> setVoiceAssetSetting(
    String voiceAssetId,
    CharacterSettingSlot which,
    String? json,
  ) => into(voiceAssetSettings).insert(
    VoiceAssetSettingsCompanion.insert(
      voiceAssetId: voiceAssetId,
      chainJson: which == CharacterSettingSlot.chain
          ? Value(json)
          : const Value.absent(),
      liveJson: which == CharacterSettingSlot.live
          ? Value(json)
          : const Value.absent(),
    ),
    onConflict: DoUpdate(
      (_) => switch (which) {
        CharacterSettingSlot.chain => VoiceAssetSettingsCompanion(
          chainJson: Value(json),
        ),
        CharacterSettingSlot.live => VoiceAssetSettingsCompanion(
          liveJson: Value(json),
        ),
      },
    ),
  );

  /// voice asset id → chain JSON, for every character with a chain.
  Stream<Map<String, String>> watchVoiceChains() =>
      (select(voiceAssetSettings)..where((t) => t.chainJson.isNotNull()))
          .watch()
          .map((rows) => {for (final r in rows) r.voiceAssetId: r.chainJson!});

  // --- Connection × capability ---

  Stream<List<ConnectionCapability>> watchConnectionCapabilities() =>
      select(connectionCapabilities).watch();

  Future<List<ConnectionCapability>> getConnectionCapabilities() =>
      select(connectionCapabilities).get();

  Future<void> upsertConnectionCapability(
    ConnectionCapabilitiesCompanion row,
  ) => into(connectionCapabilities).insertOnConflictUpdate(row);

  Future<void> deleteConnectionCapability(String connectionId, String cap) =>
      (delete(connectionCapabilities)..where(
            (t) =>
                t.connectionId.equals(connectionId) & t.capability.equals(cap),
          ))
          .go();

  /// Sets [cap]'s automatic order to [connectionIds], first preferred.
  Future<void> reorderCapabilityConnections(
    String cap,
    List<String> connectionIds,
  ) => transaction(() async {
    for (var i = 0; i < connectionIds.length; i++) {
      await upsertConnectionCapability(
        ConnectionCapabilitiesCompanion(
          connectionId: Value(connectionIds[i]),
          capability: Value(cap),
          position: Value(i),
        ),
      );
    }
  });

  /// Sets the order of [connectionId]'s models for [cap], first preferred.
  Future<void> setCapabilityModelOrder(
    String connectionId,
    String cap,
    List<String> modelIds,
  ) => upsertConnectionCapability(
    ConnectionCapabilitiesCompanion(
      connectionId: Value(connectionId),
      capability: Value(cap),
      modelOrder: Value(jsonEncode(modelIds)),
    ),
  );

  // --- Extra models ---

  Future<List<ProviderModel>> getProviderModels() =>
      (select(providerModels)..where((t) => t.enabled.equals(true))).get();

  Stream<List<ProviderModel>> watchProviderModels() =>
      (select(providerModels)..where((t) => t.enabled.equals(true))).watch();

  Future<void> upsertProviderModel(ProviderModelsCompanion row) =>
      into(providerModels).insertOnConflictUpdate(row);

  Future<void> deleteProviderModel(String id) =>
      (delete(providerModels)..where((t) => t.id.equals(id))).go();

  // --- Capability defaults ---

  Stream<List<CapabilityDefault>> watchCapabilityDefaults() =>
      select(capabilityDefaults).watch();

  Future<List<CapabilityDefault>> getCapabilityDefaults() =>
      select(capabilityDefaults).get();

  Future<void> setCapabilityDefault(
    String capability,
    (String, String)? model, {
    String purpose = '',
  }) => model == null
      ? (delete(capabilityDefaults)..where(
              (t) =>
                  t.capability.equals(capability) & t.purpose.equals(purpose),
            ))
            .go()
      : into(capabilityDefaults).insertOnConflictUpdate(
          CapabilityDefaultsCompanion.insert(
            capability: capability,
            purpose: Value(purpose),
            connectionId: model.$1,
            modelId: model.$2,
          ),
        );
}
