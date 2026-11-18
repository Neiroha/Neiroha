import 'schema_editor.dart';

// Historical schema from 35775f6.
Future<void> upgradeToV12(SchemaEditor editor) async {
  await editor.ensureTable('app_settings', '''
  CREATE TABLE "app_settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    PRIMARY KEY ("key")
  )
  ''');
  await editor.addColumns('voice_assets', {'folder_slug': "TEXT NULL"});
  await editor.addColumns('quick_tts_histories', {
    'missing': "INTEGER NOT NULL DEFAULT 0 CHECK (\"missing\" IN (0, 1))",
  });
  await editor.addColumns('phase_tts_projects', {'folder_slug': "TEXT NULL"});
  await editor.addColumns('phase_tts_segments', {
    'missing': "INTEGER NOT NULL DEFAULT 0 CHECK (\"missing\" IN (0, 1))",
  });
  await editor.addColumns('dialog_tts_projects', {'folder_slug': "TEXT NULL"});
  await editor.addColumns('dialog_tts_lines', {
    'missing': "INTEGER NOT NULL DEFAULT 0 CHECK (\"missing\" IN (0, 1))",
  });
  await editor.addColumns('audio_tracks', {
    'missing': "INTEGER NOT NULL DEFAULT 0 CHECK (\"missing\" IN (0, 1))",
  });
  await editor.addColumns('timeline_clips', {
    'missing': "INTEGER NOT NULL DEFAULT 0 CHECK (\"missing\" IN (0, 1))",
  });
}
