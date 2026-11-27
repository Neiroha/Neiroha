import 'dart:convert';

import 'package:neiroha/data/ai/protocols/http/streaming_post.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// Streams an OpenAI-shaped text answer as deltas.
///
/// Chat Completions: `stream: true`, deltas in `choices[0].delta.content`.
/// Responses: `stream: true`, deltas in `response.output_text.delta` events;
/// `response.failed` / `error` events become exceptions.
Stream<String> streamOpenAiText({
  required String baseUrl,
  required String apiKey,
  required String model,
  required List<LlmChatMessage> messages,
  required TtsCancelToken cancellation,
  String apiKeyHeader = 'Authorization',
  bool responses = false,
  int maxOutputTokens = 4096,
}) async* {
  final dio = openAiDio(baseUrl, apiKey, apiKeyHeader: apiKeyHeader);
  final body = responses
      ? {
          'model': model,
          'store': false,
          'stream': true,
          'max_output_tokens': maxOutputTokens,
          'input': [
            for (final m in messages)
              {
                'role': m.role,
                'content': [
                  {
                    'type': m.role == 'assistant'
                        ? 'output_text'
                        : 'input_text',
                    'text': m.content,
                  },
                ],
              },
          ],
        }
      : {
          'model': model,
          'stream': true,
          'messages': [for (final m in messages) m.toJson()],
          'max_tokens': maxOutputTokens,
        };
  try {
    await for (final data in sseData(
      streamingPost(
        dio,
        responses ? 'responses' : 'chat/completions',
        data: body,
        cancellation: cancellation,
        apiKey: apiKey,
      ),
    )) {
      final Object? event;
      try {
        event = jsonDecode(data);
      } on FormatException {
        continue; // keep-alive comments and vendor noise
      }
      if (event is! Map) continue;
      final delta = responses ? _responsesDelta(event) : _chatDelta(event);
      if (delta != null && delta.isNotEmpty) yield delta;
    }
  } finally {
    dio.close(force: true);
  }
}

String? _chatDelta(Map event) {
  if (event['error'] case final Map error) {
    throw AiProviderException('${error['message'] ?? error}');
  }
  final choices = event['choices'];
  if (choices is! List || choices.isEmpty || choices.first is! Map) {
    return null;
  }
  final delta = (choices.first as Map)['delta'];
  return delta is Map && delta['content'] is String
      ? delta['content'] as String
      : null;
}

String? _responsesDelta(Map event) {
  switch (event['type']) {
    case 'response.output_text.delta':
      return event['delta'] is String ? event['delta'] as String : null;
    case 'response.failed' || 'error':
      final error = event['error'] ?? (event['response'] as Map?)?['error'];
      throw AiProviderException(
        error is Map ? '${error['message'] ?? error}' : 'Response failed.',
      );
  }
  return null;
}
