import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'tts_adapter.dart';

class OpenAiCompatibleAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  late final Dio _dio;

  OpenAiCompatibleAdapter({required this.baseUrl, required this.apiKey}) {
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
      'v1/audio/speech',
      data: {
        'model': 'tts-1',
        'input': request.text,
        'voice': request.presetVoiceName ?? request.voice,
        if (request.speed != 1.0) 'speed': request.speed,
        if (request.responseFormat != null)
          'response_format': request.responseFormat,
      },
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType:
          response.headers.value('content-type') ?? 'audio/mpeg',
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('v1/models');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
