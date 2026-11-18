import 'schema_editor.dart';

// Original incremental novel migration in f72d88a.
Future<void> upgradeToV24(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'skip_punctuation_only_segments':
        "INTEGER NOT NULL DEFAULT 1 CHECK (\"skip_punctuation_only_segments\" IN (0, 1))",
  });
}
