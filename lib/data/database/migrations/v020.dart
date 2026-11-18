import 'schema_editor.dart';

// Original novel migration in 786d7f5.
Future<void> upgradeToV20(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'slice_only_at_punctuation':
        "INTEGER NOT NULL DEFAULT 1 CHECK (\"slice_only_at_punctuation\" IN (0, 1))",
  });
}
