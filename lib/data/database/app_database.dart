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
  AudioTracks,
  TimelineClips,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaults();
        },
        onUpgrade: (m, from, to) async {
          // Development: drop and recreate in reverse FK order
          await m.drop(timelineClips);
          await m.drop(audioTracks);
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
          await _seedDefaults();
        },
      );

  /// Populate the database with built-in providers and starter data so new
  /// users can immediately understand the workflow.
  Future<void> _seedDefaults() async {
    final now = DateTime.now();

    // ── Default providers (disabled — user activates after filling in URL) ──
    const providerOpenai = 'default-openai-tts';
    const providerChat = 'default-chat-tts';
    const providerCosyVoice = 'default-cosyvoice';

    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerOpenai),
      name: const Value('OpenAI TTS'),
      adapterType: const Value('openaiCompatible'),
      baseUrl: const Value('http://localhost:8880/v1'),
      defaultModelName: const Value('tts-1'),
      enabled: const Value(false),
      position: const Value(0),
    ));
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerChat),
      name: const Value('MiMo V2 TTS'),
      adapterType: const Value('chatCompletionsTts'),
      baseUrl: const Value('https://api.xiaomimimo.com/v1'),
      defaultModelName: const Value('mimo-v2-tts'),
      enabled: const Value(false),
      position: const Value(1),
    ));
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerCosyVoice),
      name: const Value('CosyVoice'),
      adapterType: const Value('cosyvoice'),
      baseUrl: const Value('http://127.0.0.1:9880'),
      defaultModelName: const Value(''),
      enabled: const Value(false),
      position: const Value(2),
    ));

    const providerGptSovits = 'default-gpt-sovits';
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerGptSovits),
      name: const Value('GPT-SoVITS'),
      adapterType: const Value('gptSovits'),
      baseUrl: const Value('http://127.0.0.1:9880'),
      defaultModelName: const Value('gpt-sovits'),
      enabled: const Value(false),
      position: const Value(3),
    ));

    const providerAzure = 'default-azure-tts';
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerAzure),
      name: const Value('Azure TTS'),
      adapterType: const Value('azureTts'),
      baseUrl: const Value('https://eastus.tts.speech.microsoft.com'),
      defaultModelName: const Value(''),
      enabled: const Value(false),
      position: const Value(4),
    ));

    const providerSystem = 'default-system-tts';
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: const Value(providerSystem),
      name: const Value('Windows System TTS'),
      adapterType: const Value('systemTts'),
      baseUrl: const Value(''),
      defaultModelName: const Value(''),
      enabled: const Value(false),
      position: const Value(5),
    ));

    // ── Default voice character ──
    const defaultCharId = 'default-character';
    await into(voiceAssets).insert(VoiceAssetsCompanion(
      id: const Value(defaultCharId),
      name: const Value('Default Voice'),
      description: const Value('Built-in starter character'),
      providerId: const Value(providerOpenai),
      taskMode: const Value('presetVoice'),
      presetVoiceName: const Value('alloy'),
      enabled: const Value(true),
    ));

    // ── Default voice bank (activated) ──
    const defaultBankId = 'default-bank';
    await into(voiceBanks).insert(VoiceBanksCompanion(
      id: const Value(defaultBankId),
      name: const Value('Default Bank'),
      description: const Value('Starter voice bank'),
      isActive: const Value(true),
      createdAt: Value(now),
    ));
    await into(voiceBankMembers).insert(VoiceBankMembersCompanion(
      id: const Value('default-bank-member'),
      bankId: const Value(defaultBankId),
      voiceAssetId: const Value(defaultCharId),
    ));

    // ── Default Dialog TTS project ──
    await into(dialogTtsProjects).insert(DialogTtsProjectsCompanion(
      id: const Value('default-dialog-project'),
      name: const Value('Sample Dialog'),
      bankId: const Value(defaultBankId),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // ── Default Phase TTS project ──
    await into(phaseTtsProjects).insert(PhaseTtsProjectsCompanion(
      id: const Value('default-phase-project'),
      name: const Value('Sample Narration'),
      bankId: const Value(defaultBankId),
      scriptText: const Value('Enter your script here.\n\nSeparate paragraphs with blank lines.\nEach paragraph becomes a segment.'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  // --- Provider CRUD ---

  // Providers are ordered by enabled-first (active on top), then by their
  // user-controlled position. Within the same group, ties fall back to name.
  Future<List<TtsProvider>> getAllProviders() => (select(ttsProviders)
        ..orderBy([
          (t) => OrderingTerm.desc(t.enabled),
          (t) => OrderingTerm.asc(t.position),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .get();

  Stream<List<TtsProvider>> watchAllProviders() => (select(ttsProviders)
        ..orderBy([
          (t) => OrderingTerm.desc(t.enabled),
          (t) => OrderingTerm.asc(t.position),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();

  Future<int> insertProvider(TtsProvidersCompanion provider) =>
      into(ttsProviders).insert(provider);

  Future<bool> updateProvider(TtsProvider provider) =>
      update(ttsProviders).replace(provider);

  Future<int> deleteProvider(String id) =>
      (delete(ttsProviders)..where((t) => t.id.equals(id))).go();

  /// Duplicate a provider with a new name. Copies all fields except id.
  Future<TtsProvider> duplicateProvider(String id, String newName) async {
    final original =
        await (select(ttsProviders)..where((t) => t.id.equals(id))).getSingle();
    final newId = const Uuid().v4();
    await into(ttsProviders).insert(TtsProvidersCompanion(
      id: Value(newId),
      name: Value(newName),
      adapterType: Value(original.adapterType),
      baseUrl: Value(original.baseUrl),
      apiKey: Value(original.apiKey),
      defaultModelName: Value(original.defaultModelName),
      enabled: const Value(false),
      position: Value(original.position + 1),
    ));
    return (select(ttsProviders)..where((t) => t.id.equals(newId))).getSingle();
  }

  /// Re-write `position` for a list of providers to match their list index.
  /// Used when the user manually reorders the provider list.
  Future<void> reorderProviders(List<String> orderedIds) => transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          await (update(ttsProviders)..where((t) => t.id.equals(orderedIds[i])))
              .write(TtsProvidersCompanion(position: Value(i)));
        }
      });

  // --- ModelBinding CRUD ---

  /// All bindings for a provider (models + voices combined).
  Future<List<ModelBinding>> getBindingsForProvider(String providerId) =>
      (select(modelBindings)..where((t) => t.providerId.equals(providerId)))
          .get();

  /// Only model entries (supportedTaskModes != 'voice').
  Future<List<ModelBinding>> getModelEntriesForProvider(String providerId) =>
      (select(modelBindings)
            ..where((t) =>
                t.providerId.equals(providerId) &
                t.supportedTaskModes.equals('voice').not()))
          .get();

  /// Only voice entries (supportedTaskModes == 'voice').
  Future<List<ModelBinding>> getVoiceEntriesForProvider(String providerId) =>
      (select(modelBindings)
            ..where((t) =>
                t.providerId.equals(providerId) &
                t.supportedTaskModes.equals('voice')))
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

  /// Get all activated banks (for API server — multiple banks can be active).
  Future<List<VoiceBank>> getActiveBanks() =>
      (select(voiceBanks)..where((t) => t.isActive.equals(true))).get();

  Stream<List<VoiceBank>> watchActiveBanks() =>
      (select(voiceBanks)..where((t) => t.isActive.equals(true))).watch();

  /// Toggle a single bank's active state without affecting others.
  Future<void> toggleBankActive(String bankId, bool active) async {
    await (update(voiceBanks)..where((t) => t.id.equals(bankId)))
        .write(VoiceBanksCompanion(isActive: Value(active)));
  }

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

  Future<int> clearQuickTtsHistoryForAsset(String assetId) =>
      (delete(quickTtsHistories)..where((t) => t.voiceAssetId.equals(assetId)))
          .go();

  Future<void> updateQuickTtsHistoryDuration(String id, double duration) =>
      (update(quickTtsHistories)..where((t) => t.id.equals(id)))
          .write(QuickTtsHistoriesCompanion(audioDuration: Value(duration)));

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

  /// Reorder a dialog line within its project by rewriting all affected
  /// `orderIndex` values in a single transaction. `oldIndex` and `newIndex`
  /// are 0-based positions in the current ordered list.
  Future<void> reorderDialogLine(
    String projectId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    await transaction(() async {
      final lines = await getDialogTtsLines(projectId);
      if (oldIndex < 0 ||
          oldIndex >= lines.length ||
          newIndex < 0 ||
          newIndex >= lines.length) {
        return;
      }
      final moved = lines.removeAt(oldIndex);
      lines.insert(newIndex, moved);
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].orderIndex != i) {
          await (update(dialogTtsLines)
                ..where((t) => t.id.equals(lines[i].id)))
              .write(DialogTtsLinesCompanion(orderIndex: Value(i)));
        }
      }
    });
  }

  // --- Timeline Clips ---

  Stream<List<TimelineClip>> watchTimelineClips(
    String projectId,
    String projectType,
  ) =>
      (select(timelineClips)
            ..where((t) =>
                t.projectId.equals(projectId) &
                t.projectType.equals(projectType))
            ..orderBy([
              (t) => OrderingTerm.asc(t.startTimeMs),
              (t) => OrderingTerm.asc(t.laneIndex),
            ]))
          .watch();

  Future<List<TimelineClip>> getTimelineClips(
    String projectId,
    String projectType,
  ) =>
      (select(timelineClips)
            ..where((t) =>
                t.projectId.equals(projectId) &
                t.projectType.equals(projectType))
            ..orderBy([(t) => OrderingTerm.asc(t.startTimeMs)]))
          .get();

  Future<int> insertTimelineClip(TimelineClipsCompanion clip) =>
      into(timelineClips).insert(clip);

  Future<bool> updateTimelineClip(TimelineClip clip) =>
      update(timelineClips).replace(clip);

  Future<int> deleteTimelineClip(String id) =>
      (delete(timelineClips)..where((t) => t.id.equals(id))).go();

  /// Replace a clip's position (lane + start). Use for drag operations.
  Future<int> moveTimelineClip(
    String id, {
    required int laneIndex,
    required int startTimeMs,
  }) =>
      (update(timelineClips)..where((t) => t.id.equals(id))).write(
        TimelineClipsCompanion(
          laneIndex: Value(laneIndex),
          startTimeMs: Value(startTimeMs),
        ),
      );

  Future<int> deleteTimelineClipsByLine(String sourceLineId) =>
      (delete(timelineClips)
            ..where((t) => t.sourceLineId.equals(sourceLineId)))
          .go();

  // --- Audio Tracks ---

  Stream<List<AudioTrack>> watchAllAudioTracks() => (select(audioTracks)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<int> insertAudioTrack(AudioTracksCompanion track) =>
      into(audioTracks).insert(track);

  Future<bool> updateAudioTrack(AudioTrack track) =>
      update(audioTracks).replace(track);

  Future<int> deleteAudioTrack(String id) =>
      (delete(audioTracks)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = await _resolveDatabaseFile(dir);
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> _resolveDatabaseFile(Directory currentDir) async {
  final currentFile = File(p.join(currentDir.path, 'neiroha.db'));
  if (await currentFile.exists()) return currentFile;

  for (final legacyFile in _legacyDatabaseCandidates(currentDir)) {
    if (await legacyFile.exists()) {
      await legacyFile.copy(currentFile.path);
      return currentFile;
    }
  }

  return currentFile;
}

Iterable<File> _legacyDatabaseCandidates(Directory currentDir) sync* {
  yield File(p.join(currentDir.path, 'q_vox_lab.db'));

  final candidateDirs = <String>{};

  void addCandidate(String path) {
    if (path != currentDir.path) {
      candidateDirs.add(path);
    }
  }

  addCandidate(currentDir.path.replaceAll(
    'com.neiroha.neiroha',
    'com.qvoxlab.q_vox_lab',
  ));
  addCandidate(currentDir.path.replaceAll(
    '${Platform.pathSeparator}neiroha',
    '${Platform.pathSeparator}q_vox_lab',
  ));
  addCandidate(currentDir.path.replaceAll(
    '${Platform.pathSeparator}Neiroha',
    '${Platform.pathSeparator}q_vox_lab',
  ));

  for (final dirPath in candidateDirs) {
    yield File(p.join(dirPath, 'neiroha.db'));
    yield File(p.join(dirPath, 'q_vox_lab.db'));
  }
}
