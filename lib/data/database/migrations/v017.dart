import 'schema_editor.dart';

// First novel tables, reconstructed from the v17–v20 steps in 786d7f5.
Future<void> upgradeToV17(SchemaEditor editor) async {
  await editor.ensureTable('novel_projects', '''
  CREATE TABLE "novel_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "narrator_voice_asset_id" TEXT NULL,
    "dialogue_voice_asset_id" TEXT NULL,
    "reader_theme" TEXT NOT NULL DEFAULT 'dark',
    "font_size" REAL NOT NULL DEFAULT 20.0,
    "line_height" REAL NOT NULL DEFAULT 1.75,
    "current_global_index" INTEGER NOT NULL DEFAULT 0,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    "folder_slug" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_chapters', '''
  CREATE TABLE "novel_chapters" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id),
    "order_index" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "source_path" TEXT NULL,
    "raw_text" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_segments', '''
  CREATE TABLE "novel_segments" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id),
    "chapter_id" TEXT NOT NULL REFERENCES novel_chapters (id),
    "global_index" INTEGER NOT NULL,
    "order_index" INTEGER NOT NULL,
    "segment_text" TEXT NOT NULL,
    "segment_type" TEXT NOT NULL DEFAULT 'narrator',
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "audio_cache_key" TEXT NULL,
    "error" TEXT NULL,
    "missing" INTEGER NOT NULL DEFAULT 0 CHECK ("missing" IN (0, 1)),
    PRIMARY KEY ("id")
  )
  ''');
}
