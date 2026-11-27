import 'package:drift/drift.dart';

import 'tables.dart';

/// One chat with a character: an AI companion (an LLM answers, the
/// character's own voice speaks) or a Realtime call. Separate from dialog
/// dubbing projects, which are scripts rather than conversations.
class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get voiceAssetId =>
      text().references(VoiceAssets, #id, onDelete: KeyAction.cascade)();

  /// `companion` or `realtime`.
  TextColumn get engine => text()();
  TextColumn get title => text()();

  /// Facts the character was asked to remember, as a JSON list of strings.
  TextColumn get memoryJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A line of a chat: what the user said, the character's reply (with its
/// emotion and delivery), or a tool the character used.
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();

  /// `user`, `character` or `tool`.
  TextColumn get role => text()();
  TextColumn get content => text()();

  /// Emotion and style of a reply; name, arguments and result of a tool.
  TextColumn get metaJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
