import 'schema_editor.dart';

// Original novel migration in 786d7f5.
Future<void> upgradeToV19(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'auto_advance_chapters':
        "INTEGER NOT NULL DEFAULT 1 CHECK (\"auto_advance_chapters\" IN (0, 1))",
  });
  if (!await editor.tableExists('novel_projects')) return;
  await editor.database.customStatement(
    'UPDATE novel_projects SET max_slice_chars = 50 WHERE max_slice_chars > 80',
  );
  await editor.database.customStatement(
    'UPDATE novel_projects SET max_slice_chars = 20 WHERE max_slice_chars < 20',
  );
}
