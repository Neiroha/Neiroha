import 'schema_editor.dart';

// Historical schema from c280a59.
Future<void> upgradeToV14(SchemaEditor editor) async {
  await editor.addColumns('timeline_clips', {'link_group_id': "TEXT NULL"});
}
