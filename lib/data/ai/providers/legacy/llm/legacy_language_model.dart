import 'dart:async';

import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// Role-AI chat through the provider's text endpoint (Gemini / MiniMax
/// paths and MiMo's `api-key` header are handled by [RoleAiConnection]).
class LegacyLanguageModel implements LanguageModel {
  LegacyLanguageModel(this.descriptor, this.row);
  @override
  final ModelDescriptor descriptor;
  final db.TtsProvider row;

  LlmChatAdapter get _chat =>
      LlmChatAdapter.fromTtsProvider(row, modelName: descriptor.id);

  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) => _chat.chat(messages: messages);

  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) => _chat.structured(
    messages: messages,
    schemaName: schemaName,
    schema: schema,
    cancellation: cancellation ?? TtsCancelToken(),
    maxOutputTokens: maxOutputTokens,
  );
}
