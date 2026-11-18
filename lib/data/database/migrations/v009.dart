import 'schema_editor.dart';

// Historical schema from b650b97.
Future<void> upgradeToV9(SchemaEditor editor) async {
  await editor.ensureTable('timeline_clips', '''
  CREATE TABLE "timeline_clips" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "project_type" TEXT NOT NULL,
    "lane_index" INTEGER NOT NULL DEFAULT 0,
    "start_time_ms" INTEGER NOT NULL DEFAULT 0,
    "duration_sec" REAL NULL,
    "audio_path" TEXT NOT NULL,
    "source_type" TEXT NOT NULL DEFAULT 'generated',
    "source_line_id" TEXT NULL,
    "label" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''');
}
