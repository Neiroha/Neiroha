import 'dart:convert';

import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';

/// Function calling over Gemini's `generateContent`: the request body for
/// a conversation with tools, and the answer read back as text or calls.
///
/// - Tools are `functionDeclarations` with their JSON Schema as
///   `parametersJsonSchema`.
/// - A call comes back as a `functionCall` part; Gemini 3 adds a
///   `thoughtSignature` that must be sent back with that call, so it is
///   kept in [LlmToolCall.signature].
/// - Results go back as `functionResponse` parts, named after their call,
///   all results of one turn in one message.
/// - JSON output (`responseJsonSchema`) cannot be combined with tools on
///   every model, so while tools are offered the reply schema is asked for
///   in the system instruction instead.
abstract final class GeminiToolChat {
  /// Ids Gemini did not give are made up here and not sent back.
  static const _madeUp = 'gemini-call-';

  static Map<String, Object?> body(
    List<ToolChatMessage> messages, {
    required List<LlmTool> tools,
    required int maxOutputTokens,
    Map<String, Object?>? thinkingConfig,
    Map<String, Object?>? replySchema,
  }) {
    final enforceSchema = replySchema != null && tools.isEmpty;
    final system = [
      for (final m in messages)
        if (m.role == 'system') m.content,
      if (replySchema != null && !enforceSchema)
        'Reply only with a JSON object of this JSON Schema, no other text:\n'
            '${jsonEncode(replySchema)}',
    ].join('\n\n');
    return {
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': _contents(messages),
      if (tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final t in tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'parametersJsonSchema': t.parameters,
                },
            ],
          },
        ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        'thinkingConfig': ?thinkingConfig,
        if (enforceSchema) ...{
          'responseMimeType': 'application/json',
          'responseJsonSchema': replySchema,
        },
      },
    };
  }

  static List<Map<String, Object?>> _contents(List<ToolChatMessage> messages) {
    final names = <String, String>{
      for (final m in messages)
        for (final call in m.toolCalls) call.id: call.name,
    };
    final contents = <Map<String, Object?>>[];
    List<Object?>? results; // the open run of tool results
    for (final m in messages) {
      if (m.role == 'system') continue;
      if (m.role == 'tool') {
        final id = m.toolCallId ?? '';
        final response = {
          'name': names[id] ?? 'unknown',
          if (!id.startsWith(_madeUp)) 'id': id,
          'response': {'result': m.content},
        };
        if (results == null) {
          results = [];
          contents.add({'role': 'user', 'parts': results});
        }
        results.add({'functionResponse': response});
        continue;
      }
      results = null;
      if (m.role == 'assistant') {
        contents.add({
          'role': 'model',
          'parts': [
            if (m.content.isNotEmpty) {'text': m.content},
            for (final call in m.toolCalls)
              {
                'functionCall': {
                  'name': call.name,
                  if (!call.id.startsWith(_madeUp)) 'id': call.id,
                  'args': _args(call.arguments),
                },
                'thoughtSignature': ?call.signature,
              },
          ],
        });
      } else {
        contents.add({
          'role': 'user',
          'parts': [
            {'text': m.content},
          ],
        });
      }
    }
    return contents;
  }

  static Object _args(String raw) {
    if (raw.trim().isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded : const <String, Object?>{};
    } on FormatException {
      return const <String, Object?>{};
    }
  }

  /// The answer's text (without thoughts) and the calls it asks for.
  static ToolChatTurn parse(Object? data) {
    if (data is! Map) {
      throw const AiProviderException('Gemini returned no JSON body.');
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final blocked = (data['promptFeedback'] as Map?)?['blockReason'];
      throw AiProviderException(
        blocked == null
            ? 'Gemini returned no candidates.'
            : 'Gemini blocked the prompt: $blocked',
      );
    }
    final first = candidates.first as Map;
    final parts = (first['content'] as Map?)?['parts'] as List? ?? const [];
    final text = StringBuffer();
    final calls = <LlmToolCall>[];
    for (final part in parts.whereType<Map>()) {
      final call = part['functionCall'];
      if (call is Map) {
        final id = call['id'];
        calls.add(
          LlmToolCall(
            id: id is String && id.isNotEmpty ? id : '$_madeUp${calls.length}',
            name: '${call['name'] ?? ''}',
            arguments: jsonEncode(call['args'] ?? const {}),
            signature: part['thoughtSignature'] as String?,
          ),
        );
      } else if (part['thought'] != true && part['text'] is String) {
        text.write(part['text']);
      }
    }
    if (calls.isEmpty &&
        text.isEmpty &&
        first['finishReason'] == 'MAX_TOKENS') {
      throw const AiProviderException(
        'Gemini used the whole output budget on thinking; raise '
        'maxOutputTokens or lower the thinking level.',
      );
    }
    return ToolChatTurn(content: text.toString(), toolCalls: calls);
  }
}
