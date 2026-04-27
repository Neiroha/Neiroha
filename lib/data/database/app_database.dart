import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../storage/path_service.dart';
import 'tables.dart';

part 'app_database.g.dart';
part 'queries/providers.dart';
part 'queries/voice.dart';
part 'queries/tts.dart';
part 'queries/projects.dart';
part 'queries/storage.dart';

@DriftDatabase(
  tables: [
    AppSettings,
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
    VideoDubProjects,
    SubtitleCues,
    AudioTracks,
    TimelineClips,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 15;

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
      await m.drop(subtitleCues);
      await m.drop(videoDubProjects);
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
      await m.drop(appSettings);
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

    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerOpenai),
        name: const Value('OpenAI TTS'),
        adapterType: const Value('openaiCompatible'),
        baseUrl: const Value('http://localhost:8880/v1'),
        defaultModelName: const Value('tts-1'),
        enabled: const Value(false),
        position: const Value(0),
      ),
    );
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerChat),
        name: const Value('MiMo V2 TTS'),
        adapterType: const Value('chatCompletionsTts'),
        baseUrl: const Value('https://api.xiaomimimo.com/v1'),
        defaultModelName: const Value('mimo-v2-tts'),
        enabled: const Value(false),
        position: const Value(1),
      ),
    );
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerCosyVoice),
        name: const Value('CosyVoice'),
        adapterType: const Value('cosyvoice'),
        baseUrl: const Value('http://127.0.0.1:9880'),
        defaultModelName: const Value(''),
        enabled: const Value(false),
        position: const Value(2),
      ),
    );

    const providerVoxCpm2 = 'default-voxcpm2-native';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerVoxCpm2),
        name: const Value('VoxCPM2 Native'),
        adapterType: const Value('voxcpm2Native'),
        baseUrl: const Value('http://127.0.0.1:8000'),
        defaultModelName: const Value('voxcpm2'),
        enabled: const Value(false),
        position: const Value(3),
      ),
    );

    const providerGptSovits = 'default-gpt-sovits';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerGptSovits),
        name: const Value('GPT-SoVITS'),
        adapterType: const Value('gptSovits'),
        baseUrl: const Value('http://127.0.0.1:9880'),
        defaultModelName: const Value('gpt-sovits'),
        enabled: const Value(false),
        position: const Value(4),
      ),
    );

    const providerAzure = 'default-azure-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerAzure),
        name: const Value('Azure TTS'),
        adapterType: const Value('azureTts'),
        baseUrl: const Value('https://eastus.tts.speech.microsoft.com'),
        defaultModelName: const Value(''),
        enabled: const Value(false),
        position: const Value(5),
      ),
    );

    const providerSystem = 'default-system-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerSystem),
        name: const Value('Windows System TTS'),
        adapterType: const Value('systemTts'),
        baseUrl: const Value(''),
        defaultModelName: const Value(''),
        enabled: const Value(false),
        position: const Value(6),
      ),
    );

    const providerGemini = 'default-gemini-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerGemini),
        name: const Value('Google Gemini TTS'),
        adapterType: const Value('geminiTts'),
        baseUrl: const Value('https://generativelanguage.googleapis.com'),
        defaultModelName: const Value('gemini-2.5-flash-preview-tts'),
        enabled: const Value(false),
        position: const Value(7),
      ),
    );

    // ── Default voice character ──
    const defaultCharId = 'default-character';
    await into(voiceAssets).insert(
      VoiceAssetsCompanion(
        id: const Value(defaultCharId),
        name: const Value('Default Voice'),
        description: const Value('Built-in starter character'),
        providerId: const Value(providerOpenai),
        taskMode: const Value('presetVoice'),
        presetVoiceName: const Value('alloy'),
        enabled: const Value(true),
      ),
    );

    // ── Default voice bank (activated) ──
    const defaultBankId = 'default-bank';
    await into(voiceBanks).insert(
      VoiceBanksCompanion(
        id: const Value(defaultBankId),
        name: const Value('Default Bank'),
        description: const Value('Starter voice bank'),
        isActive: const Value(true),
        createdAt: Value(now),
      ),
    );
    await into(voiceBankMembers).insert(
      VoiceBankMembersCompanion(
        id: const Value('default-bank-member'),
        bankId: const Value(defaultBankId),
        voiceAssetId: const Value(defaultCharId),
      ),
    );

    // ── Default Dialog TTS project ──
    await into(dialogTtsProjects).insert(
      DialogTtsProjectsCompanion(
        id: const Value('default-dialog-project'),
        name: const Value('Sample Dialog'),
        bankId: const Value(defaultBankId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // ── Default Phase TTS project ──
    await into(phaseTtsProjects).insert(
      PhaseTtsProjectsCompanion(
        id: const Value('default-phase-project'),
        name: const Value('Sample Narration'),
        bankId: const Value(defaultBankId),
        scriptText: const Value(
          'Enter your script here.\n\nSeparate paragraphs with blank lines.\nEach paragraph becomes a segment.',
        ),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    await PathService.instance.init();
    final dataDir = PathService.instance.dataRoot;
    final file = await _resolveDatabaseFile(dataDir);
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> _resolveDatabaseFile(Directory dataDir) async {
  final currentFile = File(p.join(dataDir.path, 'neiroha.db'));
  if (await currentFile.exists()) return currentFile;

  for (final legacyFile in _legacyDatabaseCandidates(dataDir)) {
    if (await legacyFile.exists()) {
      await legacyFile.copy(currentFile.path);
      return currentFile;
    }
  }

  return currentFile;
}

Iterable<File> _legacyDatabaseCandidates(Directory dataDir) sync* {
  // The previous (v0.1.x) database lived directly in the OS app-support
  // directory, not inside a `data/` subfolder. Copy from there if present.
  final legacySupport = PathService.instance.legacyAppSupportDir;
  yield File(p.join(legacySupport.path, 'neiroha.db'));
  yield File(p.join(legacySupport.path, 'q_vox_lab.db'));
  // Also check the parent of data/ for apps that used to put the DB in the
  // appRoot (portable-mode pre-migration).
  yield File(p.join(dataDir.parent.path, 'neiroha.db'));
  yield File(p.join(dataDir.parent.path, 'q_vox_lab.db'));

  final candidateDirs = <String>{};

  void addCandidate(String path) {
    if (path != legacySupport.path) {
      candidateDirs.add(path);
    }
  }

  addCandidate(
    legacySupport.path.replaceAll(
      'com.neiroha.neiroha',
      'com.qvoxlab.q_vox_lab',
    ),
  );
  addCandidate(
    legacySupport.path.replaceAll(
      '${Platform.pathSeparator}neiroha',
      '${Platform.pathSeparator}q_vox_lab',
    ),
  );
  addCandidate(
    legacySupport.path.replaceAll(
      '${Platform.pathSeparator}Neiroha',
      '${Platform.pathSeparator}q_vox_lab',
    ),
  );

  for (final dirPath in candidateDirs) {
    yield File(p.join(dirPath, 'neiroha.db'));
    yield File(p.join(dirPath, 'q_vox_lab.db'));
  }
}
