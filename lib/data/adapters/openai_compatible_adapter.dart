import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'tts_adapter.dart';

class OpenAiCompatibleAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  OpenAiCompatibleAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = 'tts-1',
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      headers: {
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      responseType: ResponseType.bytes,
    ));
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final response = await _dio.post(
      'audio/speech',
      data: {
        'model': modelName,
        'input': request.text,
        'voice': request.presetVoiceName ?? request.voice,
        if (request.speed != 1.0) 'speed': request.speed,
        if (request.responseFormat != null)
          'response_format': request.responseFormat,
      },
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/mpeg',
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('models');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
    // Try OpenAI-style /audio/voices first (e.g. CosyVoice under /v1/)
    try {
      final response = await _dio.get(
        'audio/voices',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['voices'] is List) {
          return (data['voices'] as List)
              .map((e) =>
                  e is Map ? (e['name'] ?? e.toString()) : e.toString())
              .cast<String>()
              .toList();
        }
      }
    } catch (_) {}

    // Fallback: try /speakers (SillyTavern-compatible)
    try {
      final response = await _dio.get(
        'speakers',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => e is Map ? (e['name'] ?? e.toString()) : e.toString())
            .cast<String>()
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
