import 'schema_editor.dart';

// Historical schema from 809890d.
Future<void> upgradeToV6(SchemaEditor editor) async {
  if ((await editor.column(
        'tts_providers',
        'enabled',
      ))?.readNullable<String>('dflt_value') ==
      '1') {
    await editor.rebuildTable('tts_providers', '''
    CREATE TABLE "tts_providers" (
      "id" TEXT NOT NULL,
      "name" TEXT NOT NULL,
      "adapter_type" TEXT NOT NULL,
      "base_url" TEXT NOT NULL,
      "api_key" TEXT NOT NULL DEFAULT '',
      "default_model_name" TEXT NOT NULL DEFAULT 'tts-1',
      "enabled" INTEGER NOT NULL DEFAULT 0 CHECK ("enabled" IN (0, 1)),
      "position" INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY ("id")
    )
    ''');
  } else {
    await editor.addColumns('tts_providers', {
      'position': "INTEGER NOT NULL DEFAULT 0",
    });
  }
  await editor.ensureTable('audio_tracks', '''
  CREATE TABLE "audio_tracks" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NULL,
    "audio_path" TEXT NOT NULL,
    "avatar_path" TEXT NULL,
    "ref_text" TEXT NULL,
    "ref_lang" TEXT NULL,
    "duration_sec" REAL NULL,
    "source_type" TEXT NOT NULL DEFAULT 'upload',
    "created_at" INTEGER NOT NULL,
    PRIMARY KEY ("id")
  )
  ''');
}
