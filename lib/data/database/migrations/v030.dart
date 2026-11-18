import 'schema_editor.dart';

// Insert the original disabled provider rows from 3794e7f without overriding user edits.
Future<void> upgradeToV30(SchemaEditor editor) async {
  final lastPosition = await editor.database
      .customSelect(
        'SELECT COALESCE(MAX(position), -1) AS position FROM tts_providers',
      )
      .getSingle();
  var position = lastPosition.read<int>('position') + 1;
  for (final provider in const [
    [
      'default-elevenlabs',
      'ElevenLabs',
      'elevenLabs',
      'https://api.elevenlabs.io',
      'eleven_v4',
    ],
    [
      'default-minimax-tts',
      'MiniMax Speech',
      'minimaxTts',
      'https://api.minimax.io',
      'speech-2.8-hd',
    ],
    [
      'default-index-tts',
      'IndexTTS 2.5 (Local WebUI)',
      'indexTts',
      'http://127.0.0.1:7860',
      'auto',
    ],
  ]) {
    await editor.database.customStatement(
      'INSERT OR IGNORE INTO tts_providers '
      '(id, name, adapter_type, base_url, default_model_name, enabled, position) '
      'VALUES (?, ?, ?, ?, ?, 0, ?)',
      [...provider, position++],
    );
  }
}
