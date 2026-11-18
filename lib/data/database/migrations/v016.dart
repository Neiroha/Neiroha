import 'schema_editor.dart';

// Historical schema from 57e0e14.
Future<void> upgradeToV16(SchemaEditor editor) async {
  await editor.addColumns('phase_tts_segments', {'speaker_label': "TEXT NULL"});
}
