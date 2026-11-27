import 'schema_editor.dart';

// A character's fixed sampling seed (GitHub issue #13).
Future<void> upgradeToV37(SchemaEditor editor) =>
    editor.addColumns('voice_assets', const {'seed': 'INTEGER NULL'});
