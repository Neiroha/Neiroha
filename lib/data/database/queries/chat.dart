part of '../app_database.dart';

extension AppDatabaseChatQueries on AppDatabase {
  Stream<List<ChatSession>> watchChatSessions() => (select(
    chatSessions,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<ChatSession?> getChatSession(String id) =>
      (select(chatSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<ChatSession> createChatSession({
    required String voiceAssetId,
    required String engine,
    required String title,
  }) async {
    final now = DateTime.now();
    final row = ChatSessionsCompanion.insert(
      id: const Uuid().v4(),
      voiceAssetId: voiceAssetId,
      engine: engine,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    await into(chatSessions).insert(row);
    return (await getChatSession(row.id.value))!;
  }

  Future<void> renameChatSession(String id, String title) =>
      (update(chatSessions)..where((t) => t.id.equals(id))).write(
        ChatSessionsCompanion(title: Value(title)),
      );

  Future<void> saveChatMemory(String id, List<String> facts) =>
      (update(chatSessions)..where((t) => t.id.equals(id))).write(
        ChatSessionsCompanion(memoryJson: Value(jsonEncode(facts))),
      );

  Future<void> deleteChatSession(String id) => transaction(() async {
    await (delete(chatMessages)..where((t) => t.sessionId.equals(id))).go();
    await (delete(chatSessions)..where((t) => t.id.equals(id))).go();
  });

  Stream<List<ChatMessage>> watchChatMessages(String sessionId) =>
      (select(chatMessages)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .watch();

  Future<List<ChatMessage>> getChatMessages(String sessionId) =>
      (select(chatMessages)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Appends a line and moves the session to the top of the list.
  Future<void> addChatMessage(
    String sessionId, {
    required String role,
    required String content,
    Map<String, Object?>? meta,
  }) => transaction(() async {
    final last = await customSelect(
      'SELECT COALESCE(MAX(order_index), -1) AS n FROM chat_messages '
      'WHERE session_id = ?',
      variables: [Variable.withString(sessionId)],
      readsFrom: {chatMessages},
    ).getSingle();
    final now = DateTime.now();
    await into(chatMessages).insert(
      ChatMessagesCompanion.insert(
        id: const Uuid().v4(),
        sessionId: sessionId,
        orderIndex: last.read<int>('n') + 1,
        role: role,
        content: content,
        metaJson: Value(meta == null ? null : jsonEncode(meta)),
        createdAt: now,
      ),
    );
    await (update(chatSessions)..where((t) => t.id.equals(sessionId))).write(
      ChatSessionsCompanion(updatedAt: Value(now)),
    );
  });
}
