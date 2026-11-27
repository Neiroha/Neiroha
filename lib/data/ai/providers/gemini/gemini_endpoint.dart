import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';

/// Google AI Studio (Gemini API) base URL and key. Native REST calls use
/// `x-goog-api-key`; the Live WebSocket takes the key as `?key=`.
class GeminiEndpoint {
  GeminiEndpoint(String baseUrl, this.apiKey)
    : baseUrl = _normalize(baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl);

  static const defaultBaseUrl = 'https://generativelanguage.googleapis.com';
  static const _livePath =
      'ws/google.ai.generativelanguage.v1beta.GenerativeService.'
      'BidiGenerateContent';

  /// Origin with a trailing slash, without `/v1beta` or `/openai`.
  final String baseUrl;
  final String apiKey;

  static String _normalize(String raw) {
    final uri = Uri.parse(raw.trim());
    final path = uri.path.replaceFirst(
      RegExp(r'/?(v1beta|v1)(/openai)?/*$'),
      '',
    );
    final clean = uri.replace(path: path.endsWith('/') ? path : '$path/');
    return clean.toString();
  }

  /// Dio rooted at `{base}/v1beta/`.
  Dio dio({Duration timeout = const Duration(minutes: 3)}) => openAiDio(
    Uri.parse(baseUrl).resolve('v1beta/').toString(),
    apiKey,
    apiKeyHeader: 'x-goog-api-key',
    timeout: timeout,
  );

  Uri get liveUri {
    final base = Uri.parse(baseUrl);
    return base
        .resolve(_livePath)
        .replace(
          scheme: base.scheme == 'http' ? 'ws' : 'wss',
          queryParameters: {if (apiKey.isNotEmpty) 'key': apiKey},
        );
  }
}
