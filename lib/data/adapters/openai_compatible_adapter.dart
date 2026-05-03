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
    // Helper to parse a voice list from various server response shapes.
    List<String>? parseVoiceList(dynamic data) {
      List? list;
      if (data is Map) {
        // {"voices": [...]} or {"data": [...]}
        list = (data['voices'] ?? data['data']) as List?;
      } else if (data is List) {
        list = data;
      }
      if (list == null || list.isEmpty) return null;
      return list
          .map((e) => e is Map
              ? ((e['name'] ?? e['voice_id'] ?? e.toString()) as Object).toString()
              : e.toString())
          .toList();
    }

    // 1. Try OpenAI-style /audio/voices (relative to base URL, e.g. /v1/audio/voices)
    try {
      final response = await _dio.get(
        'audio/voices',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200) {
        final voices = parseVoiceList(response.data);
        if (voices != null && voices.isNotEmpty) return voices;
      }
    } catch (_) {}

    // 2. Try /speakers relative to base URL (e.g. /v1/speakers)
    try {
      final response = await _dio.get(
        'speakers',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200) {
        final voices = parseVoiceList(response.data);
        if (voices != null && voices.isNotEmpty) return voices;
      }
    } catch (_) {}

    // 3. Root-level /speakers fallback — handles when base URL has a path
    //    prefix like /v1 but speakers are served at the server root.
    try {
      final uri = Uri.parse(baseUrl);
      if (uri.pathSegments.isNotEmpty) {
        final port = uri.hasPort ? ':${uri.port}' : '';
        final rootBase = '${uri.scheme}://${uri.host}$port/';
        final rootDio = Dio(BaseOptions(
          baseUrl: rootBase,
          headers: _dio.options.headers,
          responseType: ResponseType.json,
        ));
        final response = await rootDio.get('speakers');
        if (response.statusCode == 200) {
          final voices = parseVoiceList(response.data);
          if (voices != null && voices.isNotEmpty) return voices;
        }
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<List<ModelInfo>> getModels() async {
    try {
      final response = await _dio.get(
        'models',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['data'] is List) {
          return (data['data'] as List)
              .map((e) {
                final id = e is Map ? (e['id'] ?? '') as String : e.toString();
                return ModelInfo(id: id, name: id);
              })
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
