import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/data/storage/export_prefs.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/novel_dialogue_rules_service.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';
import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/server/api_server.dart';

/// Single database instance for the app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Disk-backed storage orchestration (voice-asset root, sync, clear-all).
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(databaseProvider));
});

/// TXT/folder import pipeline for the lightweight Novel Reader.
final novelImportServiceProvider = Provider<NovelImportService>((ref) {
  return NovelImportService(
    ref.watch(databaseProvider),
    ref.watch(storageServiceProvider),
  );
});

/// System `ffmpeg` resolver. Used by waveform extraction + media import.
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  return FFmpegService(ref.watch(databaseProvider));
});

/// User-configurable export defaults (audio format / video + audio codecs)
/// persisted in `AppSettings`. Reads/writes go through this service; the
/// settings screen edits the underlying keys.
final exportPrefsServiceProvider = Provider<ExportPrefsService>((ref) {
  return ExportPrefsService(ref.watch(databaseProvider));
});

/// Global text-splitting rules (newline / regex). Shared across every Phase
/// TTS project so the user's regex collection is a single source of truth.
final splitRulesServiceProvider = Provider<SplitRulesService>((ref) {
  return SplitRulesService(ref.watch(databaseProvider));
});

/// Loaded list of [SplitRule]. Invalidate after a save to refresh consumers.
final splitRulesProvider = FutureProvider((ref) {
  return ref.watch(splitRulesServiceProvider).load();
});

/// Global rules for detecting dialogue spans in imported novel text.
final novelDialogueRulesServiceProvider = Provider<NovelDialogueRulesService>((
  ref,
) {
  return NovelDialogueRulesService(ref.watch(databaseProvider));
});

final novelDialogueRulesProvider = FutureProvider((ref) {
  return ref.watch(novelDialogueRulesServiceProvider).load();
});

/// Per-segment Phase TTS generation overrides, such as one sentence's
/// temporary instruction/emotion prompt.
final phaseSegmentSettingsFileServiceProvider =
    Provider<PhaseSegmentSettingsFileService>((ref) {
      return PhaseSegmentSettingsFileService();
    });

/// Probes `ffmpeg -version` once per session. Watch this in the Settings
/// screen (so the badge updates after the user changes the path) and in
/// the Video Dub editor (so the waveform banner toggles). Invalidate via
/// `ref.invalidate(ffmpegAvailabilityProvider)` after the override changes.
final ffmpegAvailabilityProvider = FutureProvider<bool>((ref) async {
  final svc = ref.watch(ffmpegServiceProvider);
  return svc.isAvailable();
});

/// Fires on startup: loads the user's voice-asset root override from SQLite
/// and runs an initial missing-file scan. UI can watch this to show a badge
/// when archived audio has drifted out of sync with disk.
///
/// The future is resolved once per app session; call
/// `ref.invalidate(storageStartupProvider)` after the user changes the root
/// or runs a manual sync to refresh.
final storageStartupProvider = FutureProvider<StorageScanReport>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  await storage.applyPersistedRoot();
  return storage.scan();
});

/// API server instance.
final apiServerProvider = Provider<ApiServer>((ref) {
  final db = ref.watch(databaseProvider);
  return ApiServer(db: db);
});

/// Stream of all providers from the database.
final ttsProvidersStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllProviders();
});

/// Stream of all voice assets from the database.
final voiceAssetsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllVoiceAssets();
});

/// Stream of all voice banks.
final voiceBanksStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllBanks();
});

/// The currently active voice bank (only one at a time).
final activeBankStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveBank();
});

/// Members of a specific bank — keyed by bankId.
final bankMembersStreamProvider =
    StreamProvider.family<List<VoiceBankMember>, String>((ref, bankId) {
      final db = ref.watch(databaseProvider);
      return db.watchBankMembers(bankId);
    });

/// Quick TTS history stream.
final quickTtsHistoryStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchQuickTtsHistory();
});

/// Phase TTS projects stream.
final phaseTtsProjectsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPhaseTtsProjects();
});

/// Phase TTS segments for a project.
final phaseTtsSegmentsStreamProvider =
    StreamProvider.family<List<PhaseTtsSegment>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.watchPhaseTtsSegments(projectId);
    });

/// Novel Reader projects stream.
final novelProjectsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchNovelProjects();
});

/// Novel Reader chapters for a project.
final novelChaptersStreamProvider =
    StreamProvider.family<List<NovelChapter>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.watchNovelChapters(projectId);
    });

/// Novel Reader segments for a project.
final novelSegmentsStreamProvider =
    StreamProvider.family<List<NovelSegment>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.watchNovelSegments(projectId);
    });

/// Dialog TTS projects stream.
final dialogTtsProjectsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchDialogTtsProjects();
});

/// Dialog TTS lines for a project.
final dialogTtsLinesStreamProvider =
    StreamProvider.family<List<DialogTtsLine>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.watchDialogTtsLines(projectId);
    });

/// Video Dub projects stream (dubbing workstation projects).
final videoDubProjectsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchVideoDubProjects();
});

/// Subtitle cues for a Video Dub project.
final subtitleCuesStreamProvider =
    StreamProvider.family<List<SubtitleCue>, String>((ref, projectId) {
      final db = ref.watch(databaseProvider);
      return db.watchSubtitleCues(projectId);
    });

/// Timeline clips for a project. Key is "$projectType:$projectId" so the
/// family works across both Dialog and Phase TTS projects.
final timelineClipsStreamProvider =
    StreamProvider.family<List<TimelineClip>, String>((ref, key) {
      final parts = key.split(':');
      if (parts.length != 2) return const Stream.empty();
      final db = ref.watch(databaseProvider);
      return db.watchTimelineClips(parts[1], parts[0]);
    });

/// Stream of all audio tracks (raw audio sample library).
final audioTracksStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllAudioTracks();
});

/// Whether the API server is currently running.
final serverRunningProvider = StateProvider<bool>((ref) => false);

/// Single long-lived AudioPlayer shared across all TTS screens.
///
/// Keeping one instance for the entire app lifetime means the Windows
/// platform-channel threading warning (audioplayers_windows firing events from
/// a WinRT thread) fires at most once per app session instead of once per
/// screen navigation. Screens must cancel their stream subscriptions in
/// dispose() but must NOT call player.dispose().
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});
