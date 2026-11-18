import 'schema_editor.dart';

// Historical schema from 0f56082.
Future<void> upgradeToV27(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'playback_gap_seconds': "REAL NOT NULL DEFAULT 0.3",
  });
}
