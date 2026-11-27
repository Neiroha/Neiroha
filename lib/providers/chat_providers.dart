import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Character chats, most recent first.
final chatSessionsStreamProvider = StreamProvider<List<ChatSession>>(
  (ref) => ref.watch(databaseProvider).watchChatSessions(),
);

/// The lines of one chat, in order.
final chatMessagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>(
      (ref, sessionId) =>
          ref.watch(databaseProvider).watchChatMessages(sessionId),
    );
