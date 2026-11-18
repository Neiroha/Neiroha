import 'schema_editor.dart';

// Historical schema from be6ff41.
Future<void> upgradeToV5(SchemaEditor editor) async {
  await editor.addColumns('quick_tts_histories', {
    'audio_duration': "REAL NULL",
  });
}
