import 'dart:async';

import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/ai/protocols/openai/responses_llm_transport.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

class OpenAiLanguageModel implements LanguageModel {
  OpenAiLanguageModel(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  bool get _responses => descriptor.protocol == AiProtocol.openAiResponses;

  LlmChatAdapter get _chat => LlmChatAdapter(
    baseUrl: endpoint.baseUrl,
    apiKey: endpoint.apiKey,
    modelName: descriptor.id,
    route: _responses ? ServiceRoute.responses : ServiceRoute.chatCompletions,
  );

  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    if (!_responses) return _chat.chat(messages: messages);
    final result =
        await ResponsesLlmTransport(
          baseUrl: endpoint.baseUrl,
          apiKey: endpoint.apiKey,
          model: descriptor.id,
        ).complete(
          messages: messages,
          cancellation: cancellation ?? TtsCancelToken(),
          maxOutputTokens: maxOutputTokens,
        );
    return result.content;
  }

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
