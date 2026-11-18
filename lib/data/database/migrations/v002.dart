import 'schema_editor.dart';

// Historical schema from d4424b6.
Future<void> upgradeToV2(SchemaEditor editor) async {
  await editor.addColumns('tts_providers', {
    'default_model_name': "TEXT NOT NULL DEFAULT 'tts-1'",
  });
  if ((await editor.column(
        'voice_assets',
        'model_binding_id',
      ))?.read<int>('notnull') ==
      1) {
    await editor.rebuildTable('voice_assets', '''
    CREATE TABLE "voice_assets" (
      "id" TEXT NOT NULL,
      "name" TEXT NOT NULL,
      "description" TEXT NULL,
      "provider_id" TEXT NOT NULL REFERENCES tts_providers (id),
      "model_binding_id" TEXT NULL,
      "model_name" TEXT NULL,
      "task_mode" TEXT NOT NULL,
      "ref_audio_path" TEXT NULL,
      "ref_audio_trim_start" REAL NULL,
      "ref_audio_trim_end" REAL NULL,
      "prompt_text" TEXT NULL,
      "prompt_lang" TEXT NULL,
      "voice_instruction" TEXT NULL,
      "preset_voice_name" TEXT NULL,
      "speed" REAL NOT NULL DEFAULT 1.0,
      "enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
      PRIMARY KEY ("id")
    )
    ''');
  } else {
    await editor.addColumns('voice_assets', {
      'description': "TEXT NULL",
      'model_name': "TEXT NULL",
      'ref_audio_trim_start': "REAL NULL",
      'ref_audio_trim_end': "REAL NULL",
    });
  }
}
