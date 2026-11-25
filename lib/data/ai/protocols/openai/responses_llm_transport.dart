import 'package:dio/dio.dart';
import 'package:neiroha/domain/capabilities/service_endpoint.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

class ResponsesCompletion {
  const ResponsesCompletion(this.content, this.usage, this.format);
  final String content;
  final Map<String, dynamic> usage;
  final String format;
}

/// Explicit Responses protocol, never selected by a model-name heuristic.
/// No background jobs or tools: aborting the request closes the local transport.
class ResponsesLlmTransport {
  const ResponsesLlmTransport({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.apiKeyHeader = 'Authorization',
    this.endpointPath = 'responses',
  });
  final String baseUrl;
  final String apiKey;
  final String model;
  final String apiKeyHeader;
  final String endpointPath;

  Future<ResponsesCompletion> complete({
    required List<LlmChatMessage> messages,
    required TtsCancelToken cancellation,
    String? schemaName,
    Map<String, Object?>? schema,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final path = ServiceEndpoint.validatePath(endpointPath);
    ServiceEndpoint.validateHeader(apiKeyHeader);
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        followRedirects: false,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        headers: {
          if (apiKey.isNotEmpty)
            apiKeyHeader: apiKeyHeader.toLowerCase() == 'authorization'
                ? 'Bearer $apiKey'
                : apiKey,
        },
      ),
    );
    final cancel = CancelToken();
    final remove = cancellation.onCancel(() => cancel.cancel());
    var level = schema == null ? 2 : 0;
    try {
      while (true) {
        cancellation.throwIfCancelled();
        try {
          final response = await dio.post<dynamic>(
            path,
            cancelToken: cancel,
            data: {
              'model': model,
              'store': false,
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
              if (level < 2)
                'text': {
                  'format': level == 0
                      ? {
                          'type': 'json_schema',
                          'name': schemaName,
                          'strict': true,
                          'schema': schema,
                        }
                      : {'type': 'json_object'},
                },
            },
          );
          cancellation.throwIfCancelled();
          final data = response.data;
          if (data is! Map ||
              data['status'] != 'completed' ||
              data['error'] != null) {
            throw const LlmChatException(
              'Responses output incomplete or failed.',
            );
          }
          final output = data['output'];
          if (output is! List) {
            throw const LlmChatException('Responses output[] missing.');
          }
          final text = StringBuffer();
          for (final item in output.whereType<Map>()) {
            if (item['type'] != 'message' || item['role'] != 'assistant') {
              continue;
            }
            if (item['status'] != 'completed') {
              throw const LlmChatException('Incomplete assistant message.');
            }
            for (final content
                in (item['content'] as List? ?? []).whereType<Map>()) {
              if (content['type'] == 'refusal') {
                throw const LlmChatException('Model refused the request.');
              }
              if (content['type'] == 'output_text' &&
                  content['text'] is String) {
                text.write(content['text']);
              }
            }
          }
          if (text.isEmpty) {
            throw const LlmChatException('Responses returned no text.');
          }
          return ResponsesCompletion(
            text.toString(),
            data['usage'] is Map
                ? Map<String, dynamic>.from(data['usage'] as Map)
                : {},
            level == 0
                ? 'json_schema'
                : level == 1
                ? 'json_object'
                : 'plain',
          );
        } on DioException catch (error) {
          cancellation.throwIfCancelled();
          final body = '${error.response?.data}'.toLowerCase();
          if (allowFormatFallback &&
              level < 2 &&
              {400, 422}.contains(error.response?.statusCode) &&
              (body.contains('text.format') ||
                  body.contains('json_schema') ||
                  body.contains('json_object')) &&
              (body.contains('unsupported') ||
                  body.contains('not supported') ||
                  body.contains('unknown parameter'))) {
            level++;
            continue;
          }
          throw LlmChatException(
            'Responses request failed (${error.response?.statusCode ?? error.type.name})',
            statusCode: error.response?.statusCode,
            transportFailure: true,
          );
        }
      }
    } finally {
      remove();
      dio.close(force: true);
    }
  }
}
