import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/data/database/app_database.dart';
import 'package:q_vox_lab/server/api_server.dart';

/// Single database instance for the app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
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

/// Whether the API server is currently running.
final serverRunningProvider = StateProvider<bool>((ref) => false);
