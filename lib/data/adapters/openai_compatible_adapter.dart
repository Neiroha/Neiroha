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
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
        responseType: ResponseType.bytes,
      ),
    );
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final data = {
      'model': modelName,
      'input': request.text,
      'voice': request.presetVoiceName ?? request.voice,
      if (request.speed != 1.0) 'speed': request.speed,
      if (request.responseFormat != null)
        'response_format': request.responseFormat,
    };
    final response = await _postWithV1Fallback('audio/speech', data: data);

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/mpeg',
    );
  }

  @override
  Future<bool> healthCheck() async {
    for (final endpoint in const ['models', 'v1/models']) {
      try {
        final response = await _dio.get(
          endpoint,
          options: Options(responseType: ResponseType.json),
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
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
          .map(
            (e) => e is Map
                ? ((e['id'] ?? e['voice_id'] ?? e['name'] ?? e.toString())
                          as Object)
                      .toString()
                : e.toString(),
          )
          .where((v) => v.trim().isNotEmpty)
          .toSet()
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

    // 2. Try /v1/audio/voices for providers configured at the server root.
    try {
      final response = await _dio.get(
        'v1/audio/voices',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == 200) {
        final voices = parseVoiceList(response.data);
        if (voices != null && voices.isNotEmpty) return voices;
      }
    } catch (_) {}

    // 3. Try /speakers relative to base URL (e.g. /v1/speakers)
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

    // 4. Root-level /speakers fallback — handles when base URL has a path
    //    prefix like /v1 but speakers are served at the server root.
    try {
      final uri = Uri.parse(baseUrl);
      if (uri.pathSegments.isNotEmpty) {
        final port = uri.hasPort ? ':${uri.port}' : '';
        final rootBase = '${uri.scheme}://${uri.host}$port/';
        final rootDio = Dio(
          BaseOptions(
            baseUrl: rootBase,
            headers: _dio.options.headers,
            responseType: ResponseType.json,
          ),
        );
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
    for (final endpoint in const ['models', 'v1/models']) {
      try {
        final response = await _dio.get(
          endpoint,
          options: Options(responseType: ResponseType.json),
        );
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          if (data['data'] is List) {
            return (data['data'] as List).map((e) {
              final id = e is Map ? (e['id'] ?? '').toString() : e.toString();
              return ModelInfo(id: id, name: id);
            }).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  Future<Response<dynamic>> _postWithV1Fallback(
    String endpoint, {
    required Map<String, dynamic> data,
  }) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final pathSegments = Uri.tryParse(baseUrl)?.pathSegments ?? const [];
      if (status == 404 && !pathSegments.contains('v1')) {
        return _dio.post('v1/$endpoint', data: data);
      }
      rethrow;
    }
  }
}
