import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/llm/tool_chat.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// Function calling and strict JSON answers over OpenAI's Chat Completions
/// or Responses API (`tools`, `tool_calls` / `function_call` items, and
/// `json_schema` output).
class OpenAiToolChat {
  OpenAiToolChat({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.apiKeyHeader = 'Authorization',
    this.responses = false,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
               followRedirects: false,
               connectTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(minutes: 2),
               headers: {
                 if (apiKey.isNotEmpty)
                   apiKeyHeader: apiKeyHeader.toLowerCase() == 'authorization'
                       ? 'Bearer $apiKey'
                       : apiKey,
               },
             ),
           );

  final String baseUrl;
  final String apiKey;
  final String model;
  final String apiKeyHeader;

  /// The Responses API instead of Chat Completions.
  final bool responses;
  final Dio _dio;

  bool get _official => baseUrl.contains('api.openai.com');

  Future<ToolChatTurn> send(
    List<ToolChatMessage> messages, {
    List<LlmTool> tools = const [],
    String? schemaName,
    Map<String, Object?>? replySchema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 1024,
  }) async {
    final cancel = CancelToken();
    final remove = cancellation?.onCancel(() => cancel.cancel());
    try {
      final response = await _dio.post<dynamic>(
        responses ? 'responses' : 'chat/completions',
        cancelToken: cancel,
        data: responses
            ? responsesBody(
                model,
                messages,
                tools: tools,
                schemaName: schemaName,
                replySchema: replySchema,
                maxOutputTokens: maxOutputTokens,
              )
            : chatBody(
                model,
                messages,
                tools: tools,
                schemaName: schemaName,
                replySchema: replySchema,
                maxOutputTokens: maxOutputTokens,
                official: _official,
              ),
      );
      cancellation?.throwIfCancelled();
      return responses
          ? parseResponses(response.data)
          : parseChat(response.data);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw TtsCancelledException();
      final data = e.response?.data;
      final message = data is Map && data['error'] is Map
          ? '${(data['error'] as Map)['message']}'
          : '${e.message}';
      throw LlmChatException(message, statusCode: e.response?.statusCode);
    } finally {
      remove?.call();
    }
  }

  static Map<String, Object?> chatBody(
    String model,
    List<ToolChatMessage> messages, {
    List<LlmTool> tools = const [],
    String? schemaName,
    Map<String, Object?>? replySchema,
    int maxOutputTokens = 1024,
    bool official = true,
  }) => {
    'model': model,
    'messages': [
      for (final m in messages)
        switch (m.role) {
          'tool' => {
            'role': 'tool',
            'tool_call_id': m.toolCallId,
            'content': m.content,
          },
          'assistant' when m.toolCalls.isNotEmpty => {
            'role': 'assistant',
            'content': m.content.isEmpty ? null : m.content,
            'tool_calls': [
              for (final c in m.toolCalls)
                {
                  'id': c.id,
                  'type': 'function',
                  'function': {'name': c.name, 'arguments': c.arguments},
                },
            ],
          },
          _ => {'role': m.role, 'content': m.content},
        },
    ],
    (official ? 'max_completion_tokens' : 'max_tokens'): maxOutputTokens,
    if (tools.isNotEmpty)
      'tools': [
        for (final t in tools)
          {
            'type': 'function',
            'function': {
              'name': t.name,
              'description': t.description,
              'parameters': t.parameters,
            },
          },
      ],
    if (replySchema != null)
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': schemaName ?? 'reply',
          'strict': true,
          'schema': replySchema,
        },
      },
  };

  static ToolChatTurn parseChat(Object? data) {
    final choices = data is Map ? data['choices'] : null;
    final message = choices is List && choices.isNotEmpty
        ? (choices.first as Map)['message']
        : null;
    if (message is! Map) {
      throw const LlmChatException('The reply has no message.');
    }
    final calls = message['tool_calls'];
    return ToolChatTurn(
      content: '${message['content'] ?? ''}',
      toolCalls: [
        if (calls is List)
          for (final c in calls.whereType<Map>())
            if (c['function'] case final Map f)
              LlmToolCall(
                id: '${c['id']}',
                name: '${f['name']}',
                arguments: '${f['arguments'] ?? '{}'}',
              ),
      ],
    );
  }

  static Map<String, Object?> responsesBody(
    String model,
    List<ToolChatMessage> messages, {
    List<LlmTool> tools = const [],
    String? schemaName,
    Map<String, Object?>? replySchema,
    int maxOutputTokens = 1024,
  }) => {
    'model': model,
    'store': false,
    'max_output_tokens': maxOutputTokens,
    'input': [
      for (final m in messages)
        ...switch (m.role) {
          'tool' => [
            {
              'type': 'function_call_output',
              'call_id': m.toolCallId,
              'output': m.content,
            },
          ],
          'assistant' => [
            if (m.content.isNotEmpty)
              {'role': 'assistant', 'content': m.content},
            for (final c in m.toolCalls)
              {
                'type': 'function_call',
                'call_id': c.id,
                'name': c.name,
                'arguments': c.arguments,
              },
          ],
          _ => [
            {'role': m.role, 'content': m.content},
          ],
        },
    ],
    if (tools.isNotEmpty)
      'tools': [
        for (final t in tools)
          {
            'type': 'function',
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters,
          },
      ],
    if (replySchema != null)
      'text': {
        'format': {
          'type': 'json_schema',
          'name': schemaName ?? 'reply',
          'strict': true,
          'schema': replySchema,
        },
      },
  };

  static ToolChatTurn parseResponses(Object? data) {
    final output = data is Map ? data['output'] : null;
    if (output is! List) {
      throw const LlmChatException('The reply has no output.');
    }
    final text = StringBuffer();
    final calls = <LlmToolCall>[];
    for (final item in output.whereType<Map>()) {
      switch (item['type']) {
        case 'function_call':
          calls.add(
            LlmToolCall(
              id: '${item['call_id']}',
              name: '${item['name']}',
              arguments: '${item['arguments'] ?? '{}'}',
            ),
          );
        case 'message':
          for (final part in (item['content'] as List? ?? const [])) {
            if (part is Map && part['type'] == 'output_text') {
              text.write(part['text'] ?? '');
            }
          }
      }
    }
    return ToolChatTurn(content: text.toString(), toolCalls: calls);
  }
}

/// Decodes a tool call's arguments; a malformed object becomes empty.
Map<String, Object?> toolArguments(String raw) {
  try {
    final decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}
