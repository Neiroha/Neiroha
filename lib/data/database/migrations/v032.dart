import 'schema_editor.dart';

// Insert the original disabled provider rows from 643164b without overriding user edits.
Future<void> upgradeToV32(SchemaEditor editor) async {
  await editor.database.customStatement(
    'INSERT OR IGNORE INTO tts_providers '
    '(id, name, adapter_type, base_url, default_model_name, enabled, position) '
    'VALUES (?, ?, ?, ?, ?, 0, (SELECT COALESCE(MAX(position), -1) + 1 FROM tts_providers))',
    const [
      'default-openai-official',
      'OpenAI',
      'openaiTts',
      'https://api.openai.com/v1',
      'gpt-realtime-2.1-mini',
    ],
  );
}
