import 'package:dio/dio.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

/// One message in an OpenAI-compatible chat-completions request.
class LlmChatMessage {
  final String role; // system | user | assistant
  final String content;

  const LlmChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Thrown when the LLM response is missing the expected fields, the HTTP
/// call fails, or the JSON cannot be parsed.
class LlmChatException implements Exception {
  final String message;
  const LlmChatException(this.message);
  @override
  String toString() => 'LlmChatException: $message';
}

/// OpenAI-compatible chat-completions client used for LLM calls (role
/// assignment, future agent features). Reuses the same provider entries
/// the TTS adapters consume — caller picks `baseUrl`/`apiKey`/`modelName`
/// from a `TtsProvider` row.
///
/// `apiKeyHeader` defaults to `Authorization` (Bearer) which works for
/// OpenAI proper and most compatibles; pass `'api-key'` for MiMo-style
/// endpoints that authenticate with a raw key header.
class LlmChatAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  final String apiKeyHeader;
  late final Dio _dio;

  LlmChatAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.apiKeyHeader = 'Authorization',
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        headers: {
          apiKeyHeader: apiKeyHeader == 'Authorization'
              ? 'Bearer $apiKey'
              : apiKey,
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Build an adapter from one of the rows in the `TtsProviders` table.
  /// MiMo-style entries (`chatCompletionsTts` adapter type) authenticate
  /// with a raw `api-key` header; everything else uses the standard
  /// `Authorization: Bearer …` form.
  factory LlmChatAdapter.fromTtsProvider(
    db.TtsProvider provider, {
    required String modelName,
  }) {
    return LlmChatAdapter(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      modelName: modelName,
      apiKeyHeader: provider.adapterType == 'chatCompletionsTts'
          ? 'api-key'
          : 'Authorization',
    );
  }

  /// POST `/chat/completions` and return `choices[0].message.content` as a
  /// plain string. When [jsonMode] is true the request asks for
  /// `response_format: {type: json_object}`; if the provider rejects that
  /// field (some compatibles don't implement it) the call retries once
  /// without it before bubbling the error.
  Future<String> chat({
    required List<LlmChatMessage> messages,
    double temperature = 0.1,
    bool jsonMode = false,
    Duration? timeout,
  }) async {
    final payload = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
    };
    if (jsonMode) {
      payload['response_format'] = {'type': 'json_object'};
    }

    final options = timeout == null
        ? null
        : Options(sendTimeout: timeout, receiveTimeout: timeout);

    Response<dynamic> response;
    try {
      response = await _dio.post(
        'chat/completions',
        data: payload,
        options: options,
      );
    } on DioException catch (e) {
      if (jsonMode && _looksLikeResponseFormatRejection(e)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('response_format');
        response = await _dio.post(
          'chat/completions',
          data: fallback,
          options: options,
        );
      } else {
        throw LlmChatException(_describeDioError(e));
      }
    }

    return _extractContent(response.data);
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('models');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────── helpers ───────────────────

  static bool _looksLikeResponseFormatRejection(DioException e) {
    final status = e.response?.statusCode ?? 0;
    if (status < 400) return false;
    final body = e.response?.data?.toString().toLowerCase() ?? '';
    return body.contains('response_format');
  }

  static String _describeDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data?.toString();
    final preview = body == null
        ? ''
        : ' — ${body.length > 300 ? '${body.substring(0, 300)}…' : body}';
    if (status != null) return 'LLM HTTP $status$preview';
    return 'LLM request failed: ${e.message ?? e.type.name}';
  }

  static String _extractContent(dynamic data) {
    if (data is! Map) {
      throw const LlmChatException('LLM response was not a JSON object');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const LlmChatException('LLM response missing choices[]');
    }
    final message = (choices.first as Map?)?['message'] as Map?;
    final content = message?['content'];
    if (content is String) return content;
    // OpenAI/Anthropic-style content parts: pick the text segments.
    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is Map) {
          if (item['type'] == 'text') {
            parts.add(item['text']?.toString() ?? '');
          } else if (item.containsKey('text')) {
            parts.add(item['text']?.toString() ?? '');
          }
        } else {
          parts.add(item.toString());
        }
      }
      return parts.join();
    }
    throw const LlmChatException('LLM response had no string content');
  }
}
