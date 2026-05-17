import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
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
    NovelProjects,
    NovelChapters,
    NovelSegments,
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
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      if (from < 16) {
        await m.addColumn(phaseTtsSegments, phaseTtsSegments.speakerLabel);
      }
      if (from < 17) {
        await m.createTable(novelProjects);
        await m.createTable(novelChapters);
        await m.createTable(novelSegments);
      } else {
        if (from < 18) {
          await m.addColumn(novelProjects, novelProjects.autoTurnPage);
          await m.addColumn(novelProjects, novelProjects.autoSliceLongSegments);
          await m.addColumn(novelProjects, novelProjects.maxSliceChars);
          await customStatement(
            "UPDATE novel_projects SET reader_theme = 'dark' "
            "WHERE reader_theme = 'comfort'",
          );
        }
        if (from < 19) {
          await m.addColumn(novelProjects, novelProjects.autoAdvanceChapters);
          await customStatement(
            'UPDATE novel_projects SET max_slice_chars = 50 '
            'WHERE max_slice_chars > 80',
          );
          await customStatement(
            'UPDATE novel_projects SET max_slice_chars = 20 '
            'WHERE max_slice_chars < 20',
          );
        }
        if (from < 20) {
          await m.addColumn(
            novelProjects,
            novelProjects.sliceOnlyAtPunctuation,
          );
        }
        if (from < 21) {
          await m.addColumn(novelProjects, novelProjects.prefetchSegments);
        }
        if (from < 22) {
          await m.addColumn(novelProjects, novelProjects.cacheCurrentColor);
          await m.addColumn(novelProjects, novelProjects.cacheStaleColor);
          await m.addColumn(novelProjects, novelProjects.cacheHighlightOpacity);
        }
        if (from < 23) {
          await m.addColumn(
            novelProjects,
            novelProjects.overwriteCacheWhilePlaying,
          );
        }
        if (from < 24) {
          await m.addColumn(
            novelProjects,
            novelProjects.skipPunctuationOnlySegments,
          );
        }
      }
      if (from < 25) {
        await m.addColumn(ttsProviders, ttsProviders.maxConcurrency);
        await m.addColumn(ttsProviders, ttsProviders.requestsPerMinute);
        await m.addColumn(ttsProviders, ttsProviders.requestsPerDay);
        await m.addColumn(ttsProviders, ttsProviders.tokensPerMinute);
        await m.addColumn(ttsProviders, ttsProviders.tokensPerDay);
      }
      if (from < 26) {
        await _repairMissingCurrentSchema(m);
      }
    },
    beforeOpen: (_) async {
      await _repairMissingCurrentSchema(Migrator(this));
    },
  );

  Future<void> _repairMissingCurrentSchema(Migrator m) async {
    await _createTableIfMissing(
      'app_settings',
      () => m.createTable(appSettings),
    );
    await _createTableIfMissing(
      'tts_providers',
      () => m.createTable(ttsProviders),
    );
    await _createTableIfMissing(
      'model_bindings',
      () => m.createTable(modelBindings),
    );
    await _createTableIfMissing(
      'voice_assets',
      () => m.createTable(voiceAssets),
    );
    await _createTableIfMissing('voice_banks', () => m.createTable(voiceBanks));
    await _createTableIfMissing(
      'voice_bank_members',
      () => m.createTable(voiceBankMembers),
    );
    await _createTableIfMissing('tts_jobs', () => m.createTable(ttsJobs));
    await _createTableIfMissing(
      'quick_tts_histories',
      () => m.createTable(quickTtsHistories),
    );
    await _createTableIfMissing(
      'phase_tts_projects',
      () => m.createTable(phaseTtsProjects),
    );
    await _createTableIfMissing(
      'phase_tts_segments',
      () => m.createTable(phaseTtsSegments),
    );
    await _createTableIfMissing(
      'novel_projects',
      () => m.createTable(novelProjects),
    );
    await _createTableIfMissing(
      'novel_chapters',
      () => m.createTable(novelChapters),
    );
    await _createTableIfMissing(
      'novel_segments',
      () => m.createTable(novelSegments),
    );
    await _createTableIfMissing(
      'dialog_tts_projects',
      () => m.createTable(dialogTtsProjects),
    );
    await _createTableIfMissing(
      'dialog_tts_lines',
      () => m.createTable(dialogTtsLines),
    );
    await _createTableIfMissing(
      'video_dub_projects',
      () => m.createTable(videoDubProjects),
    );
    await _createTableIfMissing(
      'subtitle_cues',
      () => m.createTable(subtitleCues),
    );
    await _createTableIfMissing(
      'audio_tracks',
      () => m.createTable(audioTracks),
    );
    await _createTableIfMissing(
      'timeline_clips',
      () => m.createTable(timelineClips),
    );

    await _addColumnIfMissing(
      tableName: 'tts_providers',
      columnName: 'max_concurrency',
      addColumn: () => m.addColumn(ttsProviders, ttsProviders.maxConcurrency),
    );
    await _addColumnIfMissing(
      tableName: 'tts_providers',
      columnName: 'requests_per_minute',
      addColumn: () =>
          m.addColumn(ttsProviders, ttsProviders.requestsPerMinute),
    );
    await _addColumnIfMissing(
      tableName: 'tts_providers',
      columnName: 'requests_per_day',
      addColumn: () => m.addColumn(ttsProviders, ttsProviders.requestsPerDay),
    );
    await _addColumnIfMissing(
      tableName: 'tts_providers',
      columnName: 'tokens_per_minute',
      addColumn: () => m.addColumn(ttsProviders, ttsProviders.tokensPerMinute),
    );
    await _addColumnIfMissing(
      tableName: 'tts_providers',
      columnName: 'tokens_per_day',
      addColumn: () => m.addColumn(ttsProviders, ttsProviders.tokensPerDay),
    );
  }

  Future<void> _createTableIfMissing(
    String tableName,
    Future<void> Function() createTable,
  ) async {
    if (!await _tableExists(tableName)) {
      await createTable();
    }
  }

  Future<void> _addColumnIfMissing({
    required String tableName,
    required String columnName,
    required Future<void> Function() addColumn,
  }) async {
    if (await _tableExists(tableName) &&
        !await _columnExists(tableName, columnName)) {
      await addColumn();
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final row = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: [const Variable<String>('table'), Variable(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final safeTableName = tableName.replaceAll('"', '""');
    final rows = await customSelect(
      'PRAGMA table_info("$safeTableName")',
    ).get();
    return rows.any((row) => row.data['name'] == columnName);
  }

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
        name: const Value('OpenAI Compatible'),
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
        name: const Value('Xiaomi MiMo'),
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
        name: const Value('CosyVoice3 (Local)'),
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
        name: const Value('VoxCPM2 (Local)'),
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
        name: const Value('GPT-SoVITS V2 Pro (Local)'),
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
        name: const Value('Azure Speech'),
        adapterType: const Value('azureTts'),
        baseUrl: const Value('https://eastus.tts.speech.microsoft.com'),
        defaultModelName: const Value(''),
        enabled: const Value(false),
        position: const Value(5),
      ),
    );

    final platformCapabilities = PlatformCapabilities.current();
    final systemTtsProviderName = platformCapabilities.systemTtsProviderName;
    if (systemTtsProviderName != null) {
      const providerSystem = 'default-system-tts';
      await into(ttsProviders).insert(
        TtsProvidersCompanion(
          id: const Value(providerSystem),
          name: Value(systemTtsProviderName),
          adapterType: const Value('systemTts'),
          baseUrl: const Value(''),
          defaultModelName: const Value(''),
          enabled: const Value(false),
          position: const Value(6),
        ),
      );
    }

    const providerGemini = 'default-gemini-tts';
    await into(ttsProviders).insert(
      TtsProvidersCompanion(
        id: const Value(providerGemini),
        name: const Value('Google AI Studio'),
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
