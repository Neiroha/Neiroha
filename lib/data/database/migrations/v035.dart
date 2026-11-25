import 'schema_editor.dart';

// Automatic order per capability: connection priority and model order.
Future<void> upgradeToV35(SchemaEditor editor) => editor.addColumns(
  'connection_capabilities',
  const {'position': 'INTEGER NULL', 'model_order': 'TEXT NULL'},
);
