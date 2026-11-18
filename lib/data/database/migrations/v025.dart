import 'schema_editor.dart';

// Historical schema from be6af9d.
Future<void> upgradeToV25(SchemaEditor editor) async {
  await editor.addColumns('tts_providers', {
    'max_concurrency': "INTEGER NOT NULL DEFAULT 1",
    'requests_per_minute': "INTEGER NULL",
    'requests_per_day': "INTEGER NULL",
    'tokens_per_minute': "INTEGER NULL",
    'tokens_per_day': "INTEGER NULL",
  });
}
