import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  TtsProviders,
  ModelBindings,
  VoiceAssets,
  VoiceBanks,
  VoiceBankMembers,
  TtsJobs,
  QuickTtsHistories,
  PhaseTtsProjects,
  PhaseTtsSegments,
  DialogTtsProjects,
  DialogTtsLines,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Development: drop and recreate in reverse FK order
          await m.drop(dialogTtsLines);
          await m.drop(dialogTtsProjects);
          await m.drop(phaseTtsSegments);
          await m.drop(phaseTtsProjects);
          await m.drop(quickTtsHistories);
          await m.drop(ttsJobs);
          await m.drop(voiceBankMembers);
          await m.drop(voiceBanks);
          await m.drop(voiceAssets);
          await m.drop(modelBindings);
          await m.drop(ttsProviders);
          await m.createAll();
        },
      );

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

  // --- VoiceAsset / Character CRUD ---

  Future<List<VoiceAsset>> getAllVoiceAssets() => select(voiceAssets).get();

  Stream<List<VoiceAsset>> watchAllVoiceAssets() =>
      select(voiceAssets).watch();

  Future<VoiceAsset?> getVoiceAssetByName(String name) =>
      (select(voiceAssets)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<int> insertVoiceAsset(VoiceAssetsCompanion asset) =>
      into(voiceAssets).insert(asset);

  Future<bool> updateVoiceAsset(VoiceAsset asset) =>
      update(voiceAssets).replace(asset);

  Future<int> deleteVoiceAsset(String id) =>
      (delete(voiceAssets)..where((t) => t.id.equals(id))).go();

  // --- VoiceBank CRUD ---

  Stream<List<VoiceBank>> watchAllBanks() => select(voiceBanks).watch();

  Future<List<VoiceBank>> getAllBanks() => select(voiceBanks).get();

  Future<int> insertBank(VoiceBanksCompanion bank) =>
      into(voiceBanks).insert(bank);

  Future<bool> updateBank(VoiceBank bank) =>
      update(voiceBanks).replace(bank);

  Future<int> deleteBank(String id) => transaction(() async {
        // Remove members first
        await (delete(voiceBankMembers)..where((t) => t.bankId.equals(id)))
            .go();
        return (delete(voiceBanks)..where((t) => t.id.equals(id))).go();
      });

  /// Set one bank as active, deactivating all others.
  Future<void> setActiveBank(String bankId) => transaction(() async {
        await (update(voiceBanks)
              ..where((t) => t.isActive.equals(true)))
            .write(const VoiceBanksCompanion(isActive: Value(false)));
        await (update(voiceBanks)
              ..where((t) => t.id.equals(bankId)))
            .write(const VoiceBanksCompanion(isActive: Value(true)));
      });

  Future<void> deactivateAllBanks() async {
    await (update(voiceBanks)
          ..where((t) => t.isActive.equals(true)))
        .write(const VoiceBanksCompanion(isActive: Value(false)));
  }

  Stream<VoiceBank?> watchActiveBank() =>
      (select(voiceBanks)..where((t) => t.isActive.equals(true)))
          .watchSingleOrNull();

  // --- VoiceBankMember CRUD ---

  Stream<List<VoiceBankMember>> watchBankMembers(String bankId) =>
      (select(voiceBankMembers)..where((t) => t.bankId.equals(bankId)))
          .watch();

  Future<List<VoiceBankMember>> getBankMembers(String bankId) =>
      (select(voiceBankMembers)..where((t) => t.bankId.equals(bankId))).get();

  Future<int> addMemberToBank(VoiceBankMembersCompanion member) =>
      into(voiceBankMembers).insert(member);

  Future<int> removeMemberFromBank(String memberId) =>
      (delete(voiceBankMembers)..where((t) => t.id.equals(memberId))).go();

  Future<void> removeMemberByAssetAndBank(
          String bankId, String voiceAssetId) =>
      (delete(voiceBankMembers)
            ..where(
                (t) => t.bankId.equals(bankId) & t.voiceAssetId.equals(voiceAssetId)))
          .go();

  /// Duplicate a bank with all its members.
  Future<VoiceBank> duplicateBank(String bankId, String newName) =>
      transaction(() async {
        final original =
            await (select(voiceBanks)..where((t) => t.id.equals(bankId)))
                .getSingle();
        final newId = const Uuid().v4();
        await into(voiceBanks).insert(VoiceBanksCompanion(
          id: Value(newId),
          name: Value(newName),
          description: Value(original.description),
          isActive: const Value(false),
          createdAt: Value(DateTime.now()),
        ));
        final members = await getBankMembers(bankId);
        for (final m in members) {
          await into(voiceBankMembers).insert(VoiceBankMembersCompanion(
            id: Value(const Uuid().v4()),
            bankId: Value(newId),
            voiceAssetId: Value(m.voiceAssetId),
          ));
        }
        return (select(voiceBanks)..where((t) => t.id.equals(newId)))
            .getSingle();
      });

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

  // --- Quick TTS History ---

  Stream<List<QuickTtsHistory>> watchQuickTtsHistory({int limit = 100}) =>
      (select(quickTtsHistories)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> insertQuickTtsHistory(QuickTtsHistoriesCompanion entry) =>
      into(quickTtsHistories).insert(entry);

  Future<int> deleteQuickTtsHistory(String id) =>
      (delete(quickTtsHistories)..where((t) => t.id.equals(id))).go();

  Future<int> clearQuickTtsHistory() => delete(quickTtsHistories).go();

  // --- Phase TTS Projects ---

  Stream<List<PhaseTtsProject>> watchPhaseTtsProjects() =>
      (select(phaseTtsProjects)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<int> insertPhaseTtsProject(PhaseTtsProjectsCompanion project) =>
      into(phaseTtsProjects).insert(project);

  Future<bool> updatePhaseTtsProject(PhaseTtsProject project) =>
      update(phaseTtsProjects).replace(project);

  Future<int> deletePhaseTtsProject(String id) => transaction(() async {
        await (delete(phaseTtsSegments)
              ..where((t) => t.projectId.equals(id)))
            .go();
        return (delete(phaseTtsProjects)..where((t) => t.id.equals(id))).go();
      });

  // --- Phase TTS Segments ---

  Stream<List<PhaseTtsSegment>> watchPhaseTtsSegments(String projectId) =>
      (select(phaseTtsSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<PhaseTtsSegment>> getPhaseTtsSegments(String projectId) =>
      (select(phaseTtsSegments)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertPhaseTtsSegment(PhaseTtsSegmentsCompanion seg) =>
      into(phaseTtsSegments).insert(seg);

  Future<bool> updatePhaseTtsSegment(PhaseTtsSegment seg) =>
      update(phaseTtsSegments).replace(seg);

  Future<int> deletePhaseTtsSegment(String id) =>
      (delete(phaseTtsSegments)..where((t) => t.id.equals(id))).go();

  Future<int> clearPhaseTtsSegments(String projectId) =>
      (delete(phaseTtsSegments)
            ..where((t) => t.projectId.equals(projectId)))
          .go();

  // --- Dialog TTS Projects ---

  Stream<List<DialogTtsProject>> watchDialogTtsProjects() =>
      (select(dialogTtsProjects)
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<int> insertDialogTtsProject(DialogTtsProjectsCompanion project) =>
      into(dialogTtsProjects).insert(project);

  Future<bool> updateDialogTtsProject(DialogTtsProject project) =>
      update(dialogTtsProjects).replace(project);

  Future<int> deleteDialogTtsProject(String id) => transaction(() async {
        await (delete(dialogTtsLines)
              ..where((t) => t.projectId.equals(id)))
            .go();
        return (delete(dialogTtsProjects)..where((t) => t.id.equals(id))).go();
      });

  // --- Dialog TTS Lines ---

  Stream<List<DialogTtsLine>> watchDialogTtsLines(String projectId) =>
      (select(dialogTtsLines)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<DialogTtsLine>> getDialogTtsLines(String projectId) =>
      (select(dialogTtsLines)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<int> insertDialogTtsLine(DialogTtsLinesCompanion line) =>
      into(dialogTtsLines).insert(line);

  Future<bool> updateDialogTtsLine(DialogTtsLine line) =>
      update(dialogTtsLines).replace(line);

  Future<int> deleteDialogTtsLine(String id) =>
      (delete(dialogTtsLines)..where((t) => t.id.equals(id))).go();

  Future<int> clearDialogTtsLines(String projectId) =>
      (delete(dialogTtsLines)
            ..where((t) => t.projectId.equals(projectId)))
          .go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'q_vox_lab.db'));
    return NativeDatabase.createInBackground(file);
  });
}
