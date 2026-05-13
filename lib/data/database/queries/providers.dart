part of '../app_database.dart';

extension AppDatabaseProviderQueries on AppDatabase {
  // --- Provider CRUD ---

  // Providers are ordered by enabled-first (active on top), then by their
  // user-controlled position. Within the same group, ties fall back to name.
  Future<List<TtsProvider>> getAllProviders() =>
      (select(ttsProviders)..orderBy([
            (t) => OrderingTerm.desc(t.enabled),
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .get();

  Stream<List<TtsProvider>> watchAllProviders() =>
      (select(ttsProviders)..orderBy([
            (t) => OrderingTerm.desc(t.enabled),
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.name),
          ]))
          .watch();

  Future<int> insertProvider(TtsProvidersCompanion provider) =>
      into(ttsProviders).insert(provider);

  Future<bool> updateProvider(TtsProvider provider) =>
      update(ttsProviders).replace(provider);

  Future<int> deleteProvider(String id) => transaction(() async {
    final linkedAssets = await (select(
      voiceAssets,
    )..where((t) => t.providerId.equals(id))).get();
    for (final asset in linkedAssets) {
      await deleteVoiceAsset(asset.id);
    }
    await (delete(modelBindings)..where((t) => t.providerId.equals(id))).go();
    return (delete(ttsProviders)..where((t) => t.id.equals(id))).go();
  });

  /// Duplicate a provider with a new name. Copies all fields except id.
  Future<TtsProvider> duplicateProvider(String id, String newName) async {
    final original = await (select(
      ttsProviders,
    )..where((t) => t.id.equals(id))).getSingle();
    final newId = const Uuid().v4();
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: Value(newId),
        name: Value(newName),
        adapterType: Value(original.adapterType),
        baseUrl: Value(original.baseUrl),
        apiKey: Value(original.apiKey),
        defaultModelName: Value(original.defaultModelName),
        enabled: const Value(false),
        position: Value(original.position + 1),
        maxConcurrency: Value(original.maxConcurrency),
        requestsPerMinute: Value(original.requestsPerMinute),
        requestsPerDay: Value(original.requestsPerDay),
        tokensPerMinute: Value(original.tokensPerMinute),
        tokensPerDay: Value(original.tokensPerDay),
      ),
    );
    return (select(ttsProviders)..where((t) => t.id.equals(newId))).getSingle();
  }

  /// Re-write `position` for a list of providers to match their list index.
  /// Used when the user manually reorders the provider list.
  Future<void> reorderProviders(List<String> orderedIds) =>
      transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (update(ttsProviders)..where((t) => t.id.equals(orderedIds[i])))
              .write(TtsProvidersCompanion(position: Value(i)));
        }
      });

  // --- ModelBinding CRUD ---

  /// All bindings for a provider (models + voices combined).
  Future<List<ModelBinding>> getBindingsForProvider(String providerId) =>
      (select(
        modelBindings,
      )..where((t) => t.providerId.equals(providerId))).get();

  /// Only model entries (supportedTaskModes != 'voice').
  Future<List<ModelBinding>> getModelEntriesForProvider(String providerId) =>
      (select(modelBindings)..where(
            (t) =>
                t.providerId.equals(providerId) &
                t.supportedTaskModes.equals('voice').not(),
          ))
          .get();

  /// Only voice entries (supportedTaskModes == 'voice').
  Future<List<ModelBinding>> getVoiceEntriesForProvider(String providerId) =>
      (select(modelBindings)..where(
            (t) =>
                t.providerId.equals(providerId) &
                t.supportedTaskModes.equals('voice'),
          ))
          .get();

  Future<int> insertBinding(ModelBindingsCompanion binding) =>
      into(modelBindings).insert(binding);

  Future<int> deleteBinding(String id) => transaction(() async {
    await (update(voiceAssets)..where((t) => t.modelBindingId.equals(id)))
        .write(const VoiceAssetsCompanion(modelBindingId: Value(null)));
    return (delete(modelBindings)..where((t) => t.id.equals(id))).go();
  });
}
