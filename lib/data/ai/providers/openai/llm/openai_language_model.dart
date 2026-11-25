import 'dart:async';

import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_text_stream.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_tool_chat.dart';
import 'package:neiroha/data/ai/protocols/openai/responses_llm_transport.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

class OpenAiLanguageModel
    implements StreamingLanguageModel, ToolCallingLanguageModel {
  OpenAiLanguageModel(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  bool get _responses => descriptor.protocol == AiProtocol.openAiResponses;

  LlmChatAdapter get _chat => LlmChatAdapter(
    baseUrl: endpoint.baseUrl,
    apiKey: endpoint.apiKey,
    modelName: descriptor.id,
    apiKeyHeader: endpoint.apiKeyHeader,
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
          apiKeyHeader: endpoint.apiKeyHeader,
        ).complete(
          messages: messages,
          cancellation: cancellation ?? TtsCancelToken(),
          maxOutputTokens: maxOutputTokens,
        );
    return result.content;
  }

  @override
  Stream<String> streamText(
    List<LlmChatMessage> messages, {
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
  }) => streamOpenAiText(
    baseUrl: endpoint.baseUrl,
    apiKey: endpoint.apiKey,
    apiKeyHeader: endpoint.apiKeyHeader,
    model: descriptor.id,
    messages: messages,
    cancellation: cancellation,
    responses: _responses,
    maxOutputTokens: maxOutputTokens,
  );

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

  @override
  Future<ToolChatTurn> chatWithTools(
    List<ToolChatMessage> messages, {
    List<LlmTool> tools = const [],
    String? schemaName,
    Map<String, Object?>? replySchema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 1024,
  }) =>
      OpenAiToolChat(
        baseUrl: endpoint.baseUrl,
        apiKey: endpoint.apiKey,
        model: descriptor.id,
        apiKeyHeader: endpoint.apiKeyHeader,
        responses: _responses,
      ).send(
        messages,
        tools: tools,
        schemaName: schemaName,
        replySchema: replySchema,
        cancellation: cancellation,
        maxOutputTokens: maxOutputTokens,
      );
}
