import 'schema_editor.dart';

// Historical schema from f216cc8.
Future<void> upgradeToV31(SchemaEditor editor) async {
  await editor.addColumns('voice_assets', {
    'loudness_offset_db': "REAL NOT NULL DEFAULT 0.0",
  });
  await editor.addColumns('voice_banks', {
    'loudness_target_lufs': "REAL NOT NULL DEFAULT -16.0",
  });
  await editor.addColumns('phase_tts_projects', {
    'auto_normalize_loudness':
        "INTEGER NOT NULL DEFAULT 0 CHECK (\"auto_normalize_loudness\" IN (0, 1))",
    'merge_gap_seconds': "REAL NOT NULL DEFAULT 0.3",
    'merge_fade_in_ms': "INTEGER NOT NULL DEFAULT 10",
    'merge_fade_out_ms': "INTEGER NOT NULL DEFAULT 30",
  });
  await editor.addColumns('novel_projects', {
    'auto_normalize_loudness':
        "INTEGER NOT NULL DEFAULT 0 CHECK (\"auto_normalize_loudness\" IN (0, 1))",
  });
  await editor.addColumns('dialog_tts_projects', {
    'auto_normalize_loudness':
        "INTEGER NOT NULL DEFAULT 0 CHECK (\"auto_normalize_loudness\" IN (0, 1))",
  });
  await editor.addColumns('video_dub_projects', {
    'auto_normalize_loudness':
        "INTEGER NOT NULL DEFAULT 0 CHECK (\"auto_normalize_loudness\" IN (0, 1))",
  });
}
