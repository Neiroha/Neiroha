import 'schema_editor.dart';

// Original incremental novel migration in f72d88a.
Future<void> upgradeToV23(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'overwrite_cache_while_playing':
        "INTEGER NOT NULL DEFAULT 0 CHECK (\"overwrite_cache_while_playing\" IN (0, 1))",
  });
}
