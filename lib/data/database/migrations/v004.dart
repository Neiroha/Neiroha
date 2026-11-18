import 'schema_editor.dart';

// Historical schema from 34a4791.
Future<void> upgradeToV4(SchemaEditor editor) async {
  await editor.addColumns('voice_assets', {'avatar_path': "TEXT NULL"});
  await editor.ensureTable('voice_banks', '''
  CREATE TABLE "voice_banks" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NULL,
    "is_active" INTEGER NOT NULL DEFAULT 0 CHECK ("is_active" IN (0, 1)),
    "created_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('voice_bank_members', '''
  CREATE TABLE "voice_bank_members" (
    "id" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('quick_tts_histories', '''
  CREATE TABLE "quick_tts_histories" (
    "id" TEXT NOT NULL,
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id),
    "voice_name" TEXT NOT NULL,
    "input_text" TEXT NOT NULL,
    "audio_path" TEXT NULL,
    "error" TEXT NULL,
    "created_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('phase_tts_projects', '''
  CREATE TABLE "phase_tts_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "script_text" TEXT NOT NULL DEFAULT '',
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('phase_tts_segments', '''
  CREATE TABLE "phase_tts_segments" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES phase_tts_projects (id),
    "order_index" INTEGER NOT NULL,
    "segment_text" TEXT NOT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('dialog_tts_projects', '''
  CREATE TABLE "dialog_tts_projects" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "bank_id" TEXT NOT NULL REFERENCES voice_banks (id),
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('dialog_tts_lines', '''
  CREATE TABLE "dialog_tts_lines" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES dialog_tts_projects (id),
    "order_index" INTEGER NOT NULL,
    "line_text" TEXT NOT NULL,
    "voice_asset_id" TEXT NULL,
    "audio_path" TEXT NULL,
    "audio_duration" REAL NULL,
    "error" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''');
}
