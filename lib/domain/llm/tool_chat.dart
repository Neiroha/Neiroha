import 'package:neiroha/domain/ai/models/language_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// A function the model may call: a name, what it is for, and a JSON
/// Schema for its arguments.
class LlmTool {
  const LlmTool({
    required this.name,
    required this.description,
    this.parameters = const {
      'type': 'object',
      'properties': <String, Object?>{},
      'additionalProperties': false,
    },
  });
  final String name;
  final String description;
  final Map<String, Object?> parameters;
}

/// One call the model asked for.
class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.signature,
  });
  final String id;
  final String name;

  /// Raw JSON text, as the model wrote it.
  final String arguments;

  /// An opaque token the provider needs back with this call when the
  /// conversation continues (Gemini's thought signature).
  final String? signature;
}

/// A message of a conversation with tools: what the user said, an answer
/// (text and / or tool calls) and the result of a call.
class ToolChatMessage {
  const ToolChatMessage.system(this.content)
    : role = 'system',
      toolCalls = const [],
      toolCallId = null;
  const ToolChatMessage.user(this.content)
    : role = 'user',
      toolCalls = const [],
      toolCallId = null;
  const ToolChatMessage.assistant(this.content, {this.toolCalls = const []})
    : role = 'assistant',
      toolCallId = null;
  const ToolChatMessage.toolResult(String this.toolCallId, this.content)
    : role = 'tool',
      toolCalls = const [];

  final String role;
  final String content;
  final List<LlmToolCall> toolCalls;
  final String? toolCallId;
}

/// One answer: either calls to run (then ask again with their results) or
/// the final [content].
class ToolChatTurn {
  const ToolChatTurn({this.content = '', this.toolCalls = const []});
  final String content;
  final List<LlmToolCall> toolCalls;
}

/// A language model that can call functions and answer in a JSON Schema.
abstract interface class ToolCallingLanguageModel implements LanguageModel {
  /// [replySchema] makes the final answer a JSON object of that schema.
  Future<ToolChatTurn> chatWithTools(
    List<ToolChatMessage> messages, {
    List<LlmTool> tools,
    String? schemaName,
    Map<String, Object?>? replySchema,
    TtsCancelToken? cancellation,
    int maxOutputTokens,
  });
}
