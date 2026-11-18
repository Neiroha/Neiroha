import 'schema_editor.dart';

// Original incremental novel migration in f72d88a.
Future<void> upgradeToV22(SchemaEditor editor) async {
  await editor.addColumns('novel_projects', {
    'cache_current_color': "TEXT NOT NULL DEFAULT '#2F6B54'",
    'cache_stale_color': "TEXT NOT NULL DEFAULT '#7A5A2A'",
    'cache_highlight_opacity': "REAL NOT NULL DEFAULT 0.12",
  });
}
