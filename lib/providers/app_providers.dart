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

/// Whether the API server is currently running.
final serverRunningProvider = StateProvider<bool>((ref) => false);
