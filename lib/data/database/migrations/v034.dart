import 'schema_editor.dart';

// AI capability tables: per-character settings move out of `app_settings`;
// limits, extra models and defaults are kept per connection × capability.
Future<void> upgradeToV34(SchemaEditor editor) async {
  await editor.ensureTable(
    'voice_asset_settings',
    'CREATE TABLE "voice_asset_settings" ("voice_asset_id" TEXT NOT NULL '
        'REFERENCES voice_assets (id) ON DELETE CASCADE, "chain_json" TEXT '
        'NULL, "live_json" TEXT NULL, PRIMARY KEY ("voice_asset_id"))',
  );
  await editor.ensureTable(
    'connection_capabilities',
    'CREATE TABLE "connection_capabilities" ("connection_id" TEXT NOT NULL '
        'REFERENCES tts_providers (id) ON DELETE CASCADE, "capability" TEXT '
        'NOT NULL, "enabled" INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN '
        '(0, 1)), "max_concurrency" INTEGER NULL, "requests_per_minute" '
        'INTEGER NULL, "requests_per_day" INTEGER NULL, "tokens_per_minute" '
        'INTEGER NULL, "tokens_per_day" INTEGER NULL, "service_override" TEXT '
        'NULL, PRIMARY KEY ("connection_id", "capability"))',
  );
  await editor.ensureTable(
    'provider_models',
    'CREATE TABLE "provider_models" ("id" TEXT NOT NULL, "connection_id" '
        'TEXT NOT NULL REFERENCES tts_providers (id) ON DELETE CASCADE, '
        '"model_id" TEXT NOT NULL, "capability" TEXT NOT NULL, "route" TEXT '
        'NULL, "display_name" TEXT NULL, "features_json" TEXT NOT NULL '
        'DEFAULT \'[]\', "lifecycle" TEXT NULL, "shutdown_at" INTEGER NULL, '
        '"source" TEXT NOT NULL DEFAULT \'manual\', "enabled" INTEGER NOT '
        'NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)), PRIMARY KEY ("id"), '
        'UNIQUE ("connection_id", "model_id", "capability"))',
  );
  await editor.ensureTable(
    'capability_defaults',
    'CREATE TABLE "capability_defaults" ("capability" TEXT NOT NULL, '
        '"purpose" TEXT NOT NULL DEFAULT \'\', "connection_id" TEXT NOT NULL '
        'REFERENCES tts_providers (id) ON DELETE CASCADE, "model_id" TEXT NOT '
        'NULL, PRIMARY KEY ("capability", "purpose"))',
  );
  await _moveCharacterSettings(editor, 'voice.chain.', 'chain_json');
  await _moveCharacterSettings(editor, 'dialog.live.', 'live_json');
}

/// `app_settings` rows `<prefix><voice asset id>` → [column]. Rows of
/// deleted characters are dropped with the rest.
Future<void> _moveCharacterSettings(
  SchemaEditor editor,
  String prefix,
  String column,
) async {
  // Early release files can lack either table; nothing to move then.
  if (!await editor.tableExists('app_settings') ||
      !await editor.tableExists('voice_assets')) {
    return;
  }
  final db = editor.database;
  final from = prefix.length + 1;
  await db.customStatement(
    'INSERT INTO voice_asset_settings (voice_asset_id, $column) '
    'SELECT substr(s.key, $from), s.value FROM app_settings s '
    'JOIN voice_assets v ON v.id = substr(s.key, $from) '
    "WHERE s.key LIKE '$prefix%' AND s.value <> '' "
    'ON CONFLICT (voice_asset_id) DO UPDATE SET $column = excluded.$column',
  );
  await db.customStatement(
    "DELETE FROM app_settings WHERE key LIKE '$prefix%'",
  );
}
