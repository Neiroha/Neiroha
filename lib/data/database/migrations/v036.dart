import 'schema_editor.dart';

// Character chats: sessions with one character (AI companion or Realtime
// call) and their lines, kept apart from dialog dubbing projects.
Future<void> upgradeToV36(SchemaEditor editor) async {
  await editor.ensureTable(
    'chat_sessions',
    'CREATE TABLE "chat_sessions" ("id" TEXT NOT NULL, "voice_asset_id" TEXT '
        'NOT NULL REFERENCES voice_assets (id) ON DELETE CASCADE, "engine" '
        'TEXT NOT NULL, "title" TEXT NOT NULL, "memory_json" TEXT NOT NULL '
        'DEFAULT \'[]\', "created_at" INTEGER NOT NULL, "updated_at" INTEGER '
        'NOT NULL, PRIMARY KEY ("id"))',
  );
  await editor.ensureTable(
    'chat_messages',
    'CREATE TABLE "chat_messages" ("id" TEXT NOT NULL, "session_id" TEXT NOT '
        'NULL REFERENCES chat_sessions (id) ON DELETE CASCADE, "order_index" '
        'INTEGER NOT NULL, "role" TEXT NOT NULL, "content" TEXT NOT NULL, '
        '"meta_json" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY '
        '("id"))',
  );
}
