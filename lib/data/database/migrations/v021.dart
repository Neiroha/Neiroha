import 'schema_editor.dart';

// Original incremental novel migration in f72d88a.
Future<void> upgradeToV21(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'prefetch_segments': "INTEGER NOT NULL DEFAULT 5",
  });
}
