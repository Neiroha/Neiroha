import 'schema_editor.dart';

// Historical schema from 28042c7.
Future<void> upgradeToV13(SchemaEditor editor) async {
  await editor.ensureTable('video_dub_projects', '''
  CREATE TABLE "video_dub_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "video_path" TEXT NULL,
    "video_duration_sec" REAL NULL,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('subtitle_cues', '''
  CREATE TABLE "subtitle_cues" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES video_dub_projects (id),
    "order_index" INTEGER NOT NULL,
    "start_ms" INTEGER NOT NULL,
    "end_ms" INTEGER NOT NULL,
    "cue_text" TEXT NOT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
}
