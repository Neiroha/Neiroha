import 'schema_editor.dart';

// Built-in provider contract corrections from d4811fc.
Future<void> upgradeToV29(SchemaEditor editor) async {
  await editor.database.customStatement(
    "UPDATE tts_providers "
    "SET base_url = 'http://127.0.0.1:9880', "
    "default_model_name = 'default' "
    "WHERE id = 'default-gpt-sovits' "
    "AND adapter_type = 'gptSovits' "
    "AND base_url IN ("
    "'http://127.0.0.1:9880', "
    "'http://localhost:9880', "
    "'http://127.0.0.1:19880', "
    "'http://localhost:19880'"
    ") "
    "AND default_model_name IN ('', 'default', 'gpt-sovits')",
  );
  await editor.database.customStatement(
    "UPDATE tts_providers "
    "SET base_url = 'http://127.0.0.1:9880', "
    "default_model_name = 'default' "
    "WHERE id = 'default-cosyvoice' "
    "AND adapter_type = 'cosyvoice' "
    "AND base_url IN ("
    "'http://127.0.0.1:9880', "
    "'http://localhost:9880', "
    "'http://127.0.0.1:19890', "
    "'http://localhost:19890'"
    ") "
    "AND default_model_name IN ('', 'default')",
  );
  await editor.database.customStatement(
    "UPDATE tts_providers "
    "SET default_model_name = 'default' "
    "WHERE id = 'default-voxcpm2-native' "
    "AND adapter_type = 'voxcpm2Native' "
    "AND default_model_name IN ('', 'default', 'voxcpm2')",
  );
}
