import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';
import 'novel_role_tables.dart';
import 'database_connection.dart';
import 'migrations/database_migrations.dart';
import 'schema_version.dart';

part 'app_database.g.dart';
part 'queries/providers.dart';
part 'queries/voice.dart';
part 'queries/tts.dart';
part 'queries/projects.dart';
part 'queries/novel.dart';
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
}
