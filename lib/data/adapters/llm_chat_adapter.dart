import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'package:neiroha/domain/llm/llm_contract.dart';
export 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'responses_llm_transport.dart';
import 'package:neiroha/domain/capabilities/service_endpoint.dart';

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
  final ServiceRoute route;
  final String? endpointPath;
  late final Dio _dio;

  LlmChatAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.apiKeyHeader = 'Authorization',
    this.route = ServiceRoute.chatCompletions,
    this.endpointPath,
    HttpClientAdapter? httpClientAdapter,
  }) {
    if (route != ServiceRoute.chatCompletions &&
        route != ServiceRoute.responses) {
      throw ArgumentError('Choose a text protocol for an LLM task.');
    }
    if (endpointPath != null) ServiceEndpoint.validatePath(endpointPath!);
    ServiceEndpoint.validateHeader(apiKeyHeader);
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        followRedirects: false,
        headers: {
          apiKeyHeader: apiKeyHeader.toLowerCase() == 'authorization'
              ? 'Bearer $apiKey'
              : apiKey,
          'Content-Type': 'application/json',
        },
      ),
    );
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
  }

  /// Build an adapter from one of the rows in the `TtsProviders` table.
  /// MiMo-style entries (`chatCompletionsTts` adapter type) authenticate
  /// with a raw `api-key` header; everything else uses the standard
  /// `Authorization: Bearer …` form.
  factory LlmChatAdapter.fromTtsProvider(
    db.TtsProvider provider, {
    required String modelName,
    ServiceRoute route = ServiceRoute.chatCompletions,
    String? endpointPath,
    String? apiKeyHeader,
  }) {
    return LlmChatAdapter(
      baseUrl: provider.roleAiBaseUrl,
      apiKey: provider.apiKey,
      modelName: modelName,
      route: route,
      endpointPath: endpointPath,
      apiKeyHeader: apiKeyHeader ?? provider.roleAiKeyHeader,
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
    if (route == ServiceRoute.responses) {
      return (await _responses.complete(
        messages: messages,
        cancellation: TtsCancelToken(),
        timeout: timeout ?? const Duration(minutes: 2),
      )).content;
    }
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
        endpointPath ?? 'chat/completions',
        data: payload,
        options: options,
      );
    } on DioException catch (e) {
      if (jsonMode && _looksLikeResponseFormatRejection(e)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('response_format');
        response = await _dio.post(
          endpointPath ?? 'chat/completions',
          data: fallback,
          options: options,
        );
      } else {
        throw LlmChatException(_describeDioError(e));
      }
    }

    return _extractContent(response.data);
  }

  ResponsesLlmTransport get _responses => ResponsesLlmTransport(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: modelName,
    apiKeyHeader: apiKeyHeader,
    endpointPath: endpointPath ?? 'responses',
  );

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('models');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Prefer strict schema output. Only an explicit 400/422 protocol rejection
  /// may downgrade formatting; auth, quota, network and length errors do not.
  Future<LlmStructuredResult> structured({
    required List<LlmChatMessage> messages,
    required String schemaName,
    required Map<String, Object?> schema,
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (route == ServiceRoute.responses) {
      final result = await _responses.complete(
        messages: messages,
        schemaName: schemaName,
        schema: schema,
        cancellation: cancellation,
        maxOutputTokens: maxOutputTokens,
        allowFormatFallback: allowFormatFallback,
        timeout: timeout,
      );
      final object = jsonDecode(
        result.content
            .trim()
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), ''),
      );
      if (object is! Map<String, dynamic>) {
        throw const LlmChatException('LLM output must be a JSON object');
      }
      return LlmStructuredResult(
        object,
        finishReason: 'stop',
        usage: result.usage,
        responseFormat: result.format,
      );
    }
    final cancel = CancelToken();
    final remove = cancellation.onCancel(() => cancel.cancel('Cancelled'));
    final payload = <String, dynamic>{
      'model': modelName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'max_completion_tokens': maxOutputTokens,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {'name': schemaName, 'strict': true, 'schema': schema},
      },
    };
    var formatLevel = 0;
    var tokenFallback = false;
    try {
      while (true) {
        cancellation.throwIfCancelled();
        try {
          final response = await _dio.post(
            endpointPath ?? 'chat/completions',
            data: payload,
            cancelToken: cancel,
            options: Options(sendTimeout: timeout, receiveTimeout: timeout),
          );
          cancellation.throwIfCancelled();
          final data = response.data;
          if (data is! Map ||
              data['choices'] is! List ||
              (data['choices'] as List).isEmpty) {
            throw const LlmChatException('LLM response missing choices[]');
          }
          final choice = (data['choices'] as List).first as Map;
          final reason = choice['finish_reason'] as String? ?? '';
          if (reason != 'stop') {
            throw LlmChatException('LLM did not finish normally: $reason');
          }
          final content = _extractContent(data).trim();
          final clean = content.startsWith('```')
              ? content
                    .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
                    .replaceFirst(RegExp(r'\s*```$'), '')
              : content;
          final object = jsonDecode(clean);
          if (object is! Map<String, dynamic>) {
            throw const LlmChatException('LLM output must be a JSON object');
          }
          return LlmStructuredResult(
            object,
            finishReason: reason,
            responseFormat: formatLevel == 0
                ? 'json_schema'
                : formatLevel == 1
                ? 'json_object'
                : 'plain',
            usage: data['usage'] is Map
                ? Map<String, dynamic>.from(data['usage'] as Map)
                : const {},
          );
        } on DioException catch (error) {
          cancellation.throwIfCancelled();
          final status = error.response?.statusCode;
          final body = error.response?.data.toString().toLowerCase() ?? '';
          final unsupported =
              (status == 400 || status == 422) &&
              (body.contains('unsupported') ||
                  body.contains('not supported') ||
                  body.contains('unknown parameter') ||
                  body.contains('unrecognized'));
          if (unsupported &&
              !tokenFallback &&
              body.contains('max_completion_tokens')) {
            payload['max_tokens'] = payload.remove('max_completion_tokens');
            tokenFallback = true;
          } else if (allowFormatFallback &&
              unsupported &&
              body.contains('response_format') &&
              formatLevel < 2) {
            formatLevel++;
            if (formatLevel == 1) {
              payload['response_format'] = {'type': 'json_object'};
            } else {
              payload.remove('response_format');
            }
          } else {
            throw LlmChatException(
              _describeDioError(error),
              statusCode: error.response?.statusCode,
              transportFailure: true,
            );
          }
        }
      }
    } finally {
      remove();
    }
  }

  // ─────────────────── helpers ───────────────────

  static bool _looksLikeResponseFormatRejection(DioException e) {
    final status = e.response?.statusCode ?? 0;
    if (status != 400 && status != 422) return false;
    final body = e.response?.data?.toString().toLowerCase() ?? '';
    return body.contains('response_format');
  }

  String _describeDioError(DioException e) {
    final status = e.response?.statusCode;
    String redact(String value) =>
        (apiKey.isEmpty ? value : value.replaceAll(apiKey, '[REDACTED]'))
            .replaceAll(RegExp(r'sk-[A-Za-z0-9_-]+'), '[REDACTED]');
    final body = e.response?.data == null
        ? null
        : redact(e.response!.data.toString());
    final preview = body == null
        ? ''
        : ' — ${body.length > 300 ? '${body.substring(0, 300)}…' : body}';
    if (status != null) return 'LLM HTTP $status$preview';
    final detail = e.error?.toString() ?? e.message ?? e.type.name;
    return 'LLM request failed (${e.type.name}): ${redact(detail)}';
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
