import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TtsProviders, ModelBindings, VoiceAssets, TtsJobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // --- Provider CRUD ---

  Future<List<TtsProvider>> getAllProviders() => select(ttsProviders).get();

  Stream<List<TtsProvider>> watchAllProviders() =>
      select(ttsProviders).watch();

  Future<int> insertProvider(TtsProvidersCompanion provider) =>
      into(ttsProviders).insert(provider);

  Future<bool> updateProvider(TtsProvider provider) =>
      update(ttsProviders).replace(provider);

  Future<int> deleteProvider(String id) =>
      (delete(ttsProviders)..where((t) => t.id.equals(id))).go();

  // --- ModelBinding CRUD ---

  Future<List<ModelBinding>> getBindingsForProvider(String providerId) =>
      (select(modelBindings)..where((t) => t.providerId.equals(providerId)))
          .get();

  Future<int> insertBinding(ModelBindingsCompanion binding) =>
      into(modelBindings).insert(binding);

  Future<int> deleteBinding(String id) =>
      (delete(modelBindings)..where((t) => t.id.equals(id))).go();

  // --- VoiceAsset CRUD ---

  Future<List<VoiceAsset>> getAllVoiceAssets() => select(voiceAssets).get();

  Stream<List<VoiceAsset>> watchAllVoiceAssets() =>
      select(voiceAssets).watch();

  Future<VoiceAsset?> getVoiceAssetByName(String name) =>
      (select(voiceAssets)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertVoiceAsset(VoiceAssetsCompanion asset) =>
      into(voiceAssets).insert(asset);

  Future<bool> updateVoiceAsset(VoiceAsset asset) =>
      update(voiceAssets).replace(asset);

  Future<int> deleteVoiceAsset(String id) =>
      (delete(voiceAssets)..where((t) => t.id.equals(id))).go();

  // --- Job CRUD ---

  Future<List<TtsJob>> getRecentJobs({int limit = 50}) =>
      (select(ttsJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  Stream<List<TtsJob>> watchRecentJobs({int limit = 50}) =>
      (select(ttsJobs)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> insertJob(TtsJobsCompanion job) => into(ttsJobs).insert(job);

  Future<bool> updateJob(TtsJob job) => update(ttsJobs).replace(job);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'q_vox_lab.db'));
    return NativeDatabase.createInBackground(file);
  });
}
