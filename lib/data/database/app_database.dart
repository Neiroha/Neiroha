import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';
import 'ai_tables.dart';
import 'chat_tables.dart';
import 'novel_role_tables.dart';
import 'database_connection.dart'
    if (dart.library.js_interop) 'database_connection_web.dart';
import 'migrations/database_migrations.dart';
import 'schema_version.dart';

part 'app_database.g.dart';
part 'queries/providers.dart';
part 'queries/voice.dart';
part 'queries/tts.dart';
part 'queries/projects.dart';
part 'queries/novel.dart';
part 'queries/storage.dart';
part 'queries/ai.dart';
part 'queries/chat.dart';

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
    NovelCharacters,
    NovelAnnotations,
    NovelVoiceBindings,
    NovelRoleEdits,
    DialogTtsProjects,
    DialogTtsLines,
    VideoDubProjects,
    SubtitleCues,
    AudioTracks,
    TimelineClips,
    VoiceAssetSettings,
    ConnectionCapabilities,
    ProviderModels,
    CapabilityDefaults,
    ChatSessions,
    ChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openAppConnection());
  AppDatabase.forTesting(super.e);
  AppDatabase.temporary(super.e);

  @override
  int get schemaVersion => neirohaSchemaVersion;

  @override
  MigrationStrategy get migration => databaseMigrationStrategy(this);

  /// Closes the SQLite connection without waiting for stream queries to
  /// finish. [close] waits until every watcher has seen its stream end,
  /// and Riverpod pauses the watchers of providers nobody is looking at,
  /// so on quit it could wait forever and leave SQLite to be closed by its
  /// finalizer while the process exits, which crashes.
  Future<void> closeConnection() => executor.close();
}
