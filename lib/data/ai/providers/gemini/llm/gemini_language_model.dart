import 'dart:convert';

import 'package:neiroha/data/ai/protocols/http/streaming_post.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import '../gemini_endpoint.dart';

/// Gemini text models over the native `models/{id}:generateContent` API.
/// [thinkingLevel] maps onto `thinkingConfig.thinkingLevel` when the model
/// supports thinking (Gemini 3 and newer).
class GeminiLanguageModel implements StreamingLanguageModel {
  GeminiLanguageModel(this.descriptor, this.endpoint, {this.thinkingLevel});
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;
  final ReasoningEffort? thinkingLevel;

  static Map<String, Object?> body(
    List<LlmChatMessage> messages, {
    required int maxOutputTokens,
    ReasoningEffort? thinkingLevel,
    Map<String, Object?>? schema,
  }) {
    final system = [
      for (final m in messages)
        if (m.role == 'system') m.content,
    ].join('\n\n');
    return {
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': [
        for (final m in messages)
          if (m.role != 'system')
            {
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': m.content},
              ],
            },
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
        if (thinkingLevel != null && thinkingLevel != ReasoningEffort.none)
          'thinkingConfig': {'thinkingLevel': thinkingLevel.name.toUpperCase()},
        if (schema != null) ...{
          'responseMimeType': 'application/json',
          'responseJsonSchema': schema,
        },
      },
    };
  }

  Future<(String, String, Map<String, Object?>)> _generate(
    Map<String, Object?> body,
    TtsCancelToken? cancellation,
  ) => withCancel(cancellation, endpoint.apiKey, (token) async {
    final response = await endpoint.dio().post<dynamic>(
      'models/${descriptor.id}:generateContent',
      data: body,
      cancelToken: token,
    );
    return parse(response.data);
  });

  /// (answer text without thoughts, finishReason, usageMetadata).
  static (String, String, Map<String, Object?>) parse(Object? data) {
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
    final first = Map<String, dynamic>.from(candidates.first as Map);
    final parts = (first['content'] as Map?)?['parts'] as List? ?? const [];
    final text = [
      for (final p in parts.whereType<Map>())
        if (p['thought'] != true && p['text'] is String) p['text'] as String,
    ].join();
    final usage = data['usageMetadata'];
    return (
      text,
      '${first['finishReason'] ?? 'STOP'}',
      usage is Map ? Map<String, Object?>.from(usage) : const {},
    );
  }

  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    final (text, reason, _) = await _generate(
      body(
        messages,
        maxOutputTokens: maxOutputTokens,
        thinkingLevel: thinkingLevel,
      ),
      cancellation,
    );
    if (text.isEmpty && reason == 'MAX_TOKENS') {
      throw const AiProviderException(
        'Gemini used the whole output budget on thinking; raise '
        'maxOutputTokens or lower the thinking level.',
      );
    }
    return text;
  }

  /// `streamGenerateContent?alt=sse`: each event is a partial response.
  @override
  Stream<String> streamText(
    List<LlmChatMessage> messages, {
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
  }) async* {
    var any = false;
    var reason = 'STOP';
    await for (final data in sseData(
      streamingPost(
        endpoint.dio(),
        'models/${descriptor.id}:streamGenerateContent',
        queryParameters: {'alt': 'sse'},
        data: body(
          messages,
          maxOutputTokens: maxOutputTokens,
          thinkingLevel: thinkingLevel,
        ),
        cancellation: cancellation,
        apiKey: endpoint.apiKey,
      ),
    )) {
      final event = jsonDecode(data);
      // Trailing usage-only events carry no candidates.
      if (event is! Map || event['candidates'] is! List) {
        if (event is Map && event['promptFeedback'] is Map) parse(event);
        continue;
      }
      final (text, finish, _) = parse(event);
      reason = finish;
      if (text.isEmpty) continue;
      any = true;
      yield text;
    }
    if (!any && reason == 'MAX_TOKENS') {
      throw const AiProviderException(
        'Gemini used the whole output budget on thinking; raise '
        'maxOutputTokens or lower the thinking level.',
      );
    }
  }

  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    final (text, reason, usage) = await _generate(
      body(
        messages,
        maxOutputTokens: maxOutputTokens,
        thinkingLevel: thinkingLevel,
        schema: schema,
      ),
      cancellation,
    );
    final decoded = jsonDecode(text.isEmpty ? '{}' : text);
    if (decoded is! Map) {
      throw AiProviderException('Gemini returned non-object JSON ($reason).');
    }
    return LlmStructuredResult(
      Map<String, dynamic>.from(decoded),
      finishReason: reason == 'STOP' ? 'stop' : reason.toLowerCase(),
      usage: usage,
    );
  }
}
