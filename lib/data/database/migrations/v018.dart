import 'schema_editor.dart';

// Original novel migration in 786d7f5.
Future<void> upgradeToV18(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'auto_turn_page':
        "INTEGER NOT NULL DEFAULT 1 CHECK (\"auto_turn_page\" IN (0, 1))",
    'auto_slice_long_segments':
        "INTEGER NOT NULL DEFAULT 1 CHECK (\"auto_slice_long_segments\" IN (0, 1))",
    'max_slice_chars': "INTEGER NOT NULL DEFAULT 50",
  });
  if (!await editor.tableExists('novel_projects')) return;
  await editor.database.customStatement(
    "UPDATE novel_projects SET reader_theme = 'dark' WHERE reader_theme = 'comfort'",
  );
}
