import 'schema_editor.dart';

// Historical schema from a323573.
Future<void> upgradeToV33(SchemaEditor editor) async {
  await editor.ensureTable('novel_characters', '''
  CREATE TABLE "novel_characters" (
    "id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id) ON DELETE CASCADE,
    "name" TEXT NOT NULL,
    "aliases_json" TEXT NOT NULL DEFAULT '[]',
    "description" TEXT NOT NULL DEFAULT '',
    "color" INTEGER NOT NULL DEFAULT 4286487768,
    PRIMARY KEY ("id")
  )
  ''');
  await editor.ensureTable('novel_annotations', '''
  CREATE TABLE "novel_annotations" (
    "segment_id" TEXT NOT NULL REFERENCES novel_segments (id) ON DELETE CASCADE,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id) ON DELETE CASCADE,
    "text_revision" TEXT NOT NULL,
    "character_id" TEXT NULL REFERENCES novel_characters (id) ON DELETE SET NULL,
    "kind" TEXT NOT NULL DEFAULT 'narrator',
    "voice_asset_id" TEXT NULL,
    "instruction" TEXT NULL,
    "locked" INTEGER NOT NULL DEFAULT 0 CHECK ("locked" IN (0, 1)),
    "review_state" TEXT NOT NULL DEFAULT 'pending',
    "reason" TEXT NOT NULL DEFAULT '',
    "change_id" TEXT NOT NULL,
    PRIMARY KEY ("segment_id")
  )
  ''');
  await editor.ensureTable('novel_voice_bindings', '''
  CREATE TABLE "novel_voice_bindings" (
    "character_id" TEXT NOT NULL REFERENCES novel_characters (id) ON DELETE CASCADE,
    "chapter_id" TEXT NOT NULL DEFAULT '',
    "voice_asset_id" TEXT NOT NULL REFERENCES voice_assets (id) ON DELETE CASCADE,
    "instruction" TEXT NULL,
    PRIMARY KEY ("character_id", "chapter_id")
  )
  ''');
  await editor.ensureTable('novel_role_edits', '''
  CREATE TABLE "novel_role_edits" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "project_id" TEXT NOT NULL REFERENCES novel_projects (id) ON DELETE CASCADE,
    "payload" TEXT NOT NULL,
    "created_at" INTEGER NOT NULL
  )
  ''');
}
