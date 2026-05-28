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
  int get schemaVersion => 27;

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
      if (from >= 26 && from < 27) {
        await m.addColumn(novelProjects, novelProjects.playbackGapSeconds);
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
    await _addColumnIfMissing(
      tableName: 'audio_tracks',
      columnName: 'missing',
      addColumn: () => m.addColumn(audioTracks, audioTracks.missing),
    );
    await _addColumnIfMissing(
      tableName: 'voice_assets',
      columnName: 'folder_slug',
      addColumn: () => m.addColumn(voiceAssets, voiceAssets.folderSlug),
    );
    await _addColumnIfMissing(
      tableName: 'quick_tts_histories',
      columnName: 'missing',
      addColumn: () =>
          m.addColumn(quickTtsHistories, quickTtsHistories.missing),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_projects',
      columnName: 'folder_slug',
      addColumn: () =>
          m.addColumn(phaseTtsProjects, phaseTtsProjects.folderSlug),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'speaker_label',
      addColumn: () =>
          m.addColumn(phaseTtsSegments, phaseTtsSegments.speakerLabel),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'voice_asset_id',
      addColumn: () =>
          m.addColumn(phaseTtsSegments, phaseTtsSegments.voiceAssetId),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'audio_path',
      addColumn: () =>
          m.addColumn(phaseTtsSegments, phaseTtsSegments.audioPath),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'audio_duration',
      addColumn: () =>
          m.addColumn(phaseTtsSegments, phaseTtsSegments.audioDuration),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'error',
      addColumn: () => m.addColumn(phaseTtsSegments, phaseTtsSegments.error),
    );
    await _addColumnIfMissing(
      tableName: 'phase_tts_segments',
      columnName: 'missing',
      addColumn: () => m.addColumn(phaseTtsSegments, phaseTtsSegments.missing),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'narrator_voice_asset_id',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.narratorVoiceAssetId),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'dialogue_voice_asset_id',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.dialogueVoiceAssetId),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'reader_theme',
      addColumn: () => m.addColumn(novelProjects, novelProjects.readerTheme),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'font_size',
      addColumn: () => m.addColumn(novelProjects, novelProjects.fontSize),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'line_height',
      addColumn: () => m.addColumn(novelProjects, novelProjects.lineHeight),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'auto_turn_page',
      addColumn: () => m.addColumn(novelProjects, novelProjects.autoTurnPage),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'auto_advance_chapters',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.autoAdvanceChapters),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'auto_slice_long_segments',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.autoSliceLongSegments),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'slice_only_at_punctuation',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.sliceOnlyAtPunctuation),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'max_slice_chars',
      addColumn: () => m.addColumn(novelProjects, novelProjects.maxSliceChars),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'prefetch_segments',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.prefetchSegments),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'playback_gap_seconds',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.playbackGapSeconds),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'overwrite_cache_while_playing',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.overwriteCacheWhilePlaying),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'skip_punctuation_only_segments',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.skipPunctuationOnlySegments),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'cache_current_color',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.cacheCurrentColor),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'cache_stale_color',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.cacheStaleColor),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'cache_highlight_opacity',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.cacheHighlightOpacity),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'current_global_index',
      addColumn: () =>
          m.addColumn(novelProjects, novelProjects.currentGlobalIndex),
    );
    await _addColumnIfMissing(
      tableName: 'novel_projects',
      columnName: 'folder_slug',
      addColumn: () => m.addColumn(novelProjects, novelProjects.folderSlug),
    );
    await _addColumnIfMissing(
      tableName: 'novel_chapters',
      columnName: 'source_path',
      addColumn: () => m.addColumn(novelChapters, novelChapters.sourcePath),
    );
    await _addColumnIfMissing(
      tableName: 'novel_chapters',
      columnName: 'raw_text',
      addColumn: () => m.addColumn(novelChapters, novelChapters.rawText),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'segment_type',
      addColumn: () => m.addColumn(novelSegments, novelSegments.segmentType),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'audio_path',
      addColumn: () => m.addColumn(novelSegments, novelSegments.audioPath),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'audio_duration',
      addColumn: () => m.addColumn(novelSegments, novelSegments.audioDuration),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'audio_cache_key',
      addColumn: () => m.addColumn(novelSegments, novelSegments.audioCacheKey),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'error',
      addColumn: () => m.addColumn(novelSegments, novelSegments.error),
    );
    await _addColumnIfMissing(
      tableName: 'novel_segments',
      columnName: 'missing',
      addColumn: () => m.addColumn(novelSegments, novelSegments.missing),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_projects',
      columnName: 'folder_slug',
      addColumn: () =>
          m.addColumn(dialogTtsProjects, dialogTtsProjects.folderSlug),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_lines',
      columnName: 'voice_asset_id',
      addColumn: () => m.addColumn(dialogTtsLines, dialogTtsLines.voiceAssetId),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_lines',
      columnName: 'audio_path',
      addColumn: () => m.addColumn(dialogTtsLines, dialogTtsLines.audioPath),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_lines',
      columnName: 'audio_duration',
      addColumn: () =>
          m.addColumn(dialogTtsLines, dialogTtsLines.audioDuration),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_lines',
      columnName: 'error',
      addColumn: () => m.addColumn(dialogTtsLines, dialogTtsLines.error),
    );
    await _addColumnIfMissing(
      tableName: 'dialog_tts_lines',
      columnName: 'missing',
      addColumn: () => m.addColumn(dialogTtsLines, dialogTtsLines.missing),
    );
    await _addColumnIfMissing(
      tableName: 'video_dub_projects',
      columnName: 'video_path',
      addColumn: () =>
          m.addColumn(videoDubProjects, videoDubProjects.videoPath),
    );
    await _addColumnIfMissing(
      tableName: 'video_dub_projects',
      columnName: 'video_duration_sec',
      addColumn: () =>
          m.addColumn(videoDubProjects, videoDubProjects.videoDurationSec),
    );
    await _addColumnIfMissing(
      tableName: 'video_dub_projects',
      columnName: 'folder_slug',
      addColumn: () =>
          m.addColumn(videoDubProjects, videoDubProjects.folderSlug),
    );
    await _addColumnIfMissing(
      tableName: 'subtitle_cues',
      columnName: 'voice_asset_id',
      addColumn: () => m.addColumn(subtitleCues, subtitleCues.voiceAssetId),
    );
    await _addColumnIfMissing(
      tableName: 'subtitle_cues',
      columnName: 'audio_path',
      addColumn: () => m.addColumn(subtitleCues, subtitleCues.audioPath),
    );
    await _addColumnIfMissing(
      tableName: 'subtitle_cues',
      columnName: 'audio_duration',
      addColumn: () => m.addColumn(subtitleCues, subtitleCues.audioDuration),
    );
    await _addColumnIfMissing(
      tableName: 'subtitle_cues',
      columnName: 'error',
      addColumn: () => m.addColumn(subtitleCues, subtitleCues.error),
    );
    await _addColumnIfMissing(
      tableName: 'subtitle_cues',
      columnName: 'missing',
      addColumn: () => m.addColumn(subtitleCues, subtitleCues.missing),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'lane_index',
      addColumn: () => m.addColumn(timelineClips, timelineClips.laneIndex),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'start_time_ms',
      addColumn: () => m.addColumn(timelineClips, timelineClips.startTimeMs),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'duration_sec',
      addColumn: () => m.addColumn(timelineClips, timelineClips.durationSec),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'source_type',
      addColumn: () => m.addColumn(timelineClips, timelineClips.sourceType),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'source_line_id',
      addColumn: () => m.addColumn(timelineClips, timelineClips.sourceLineId),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'label',
      addColumn: () => m.addColumn(timelineClips, timelineClips.label),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'missing',
      addColumn: () => m.addColumn(timelineClips, timelineClips.missing),
    );
    await _addColumnIfMissing(
      tableName: 'timeline_clips',
      columnName: 'link_group_id',
      addColumn: () => m.addColumn(timelineClips, timelineClips.linkGroupId),
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

  // Portable release folders must start clean. Earlier builds stored the DB
  // inside the Flutter bundle's `data/` directory and tried to copy legacy
  // app-support DBs automatically, which made fresh release extractions pick
  // up local development/user test databases.
  if (PathService.instance.isPortable) {
    return currentFile;
  }

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
