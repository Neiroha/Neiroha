import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for GPT-SoVITS TTS backend (api_v2.py style).
///
/// Endpoints used:
///   GET/POST /tts            — synthesize speech
///   GET      /set_refer_audio — change reference audio (optional)
///   GET      /set_gpt_weights — switch GPT model weights
///   GET      /set_sovits_weights — switch SoVITS model weights
///   GET      /control         — restart / exit server
class GptSovitsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  GptSovitsAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = 'gpt-sovits',
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
    final body = <String, dynamic>{
      'text': request.text,
      'text_lang': request.textLang ?? 'zh',
    };

    // Reference audio is required for GPT-SoVITS
    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      body['ref_audio_path'] = request.refAudioPath;
    }

    // Prompt text & language for reference audio
    if (request.promptText != null && request.promptText!.isNotEmpty) {
      body['prompt_text'] = request.promptText;
    }
    if (request.promptLang != null && request.promptLang!.isNotEmpty) {
      body['prompt_lang'] = request.promptLang;
    }

    // Speed
    if (request.speed != 1.0) {
      body['speed_factor'] = request.speed;
    }

    // Media type
    body['media_type'] = request.responseFormat ?? 'wav';

    // Default inference params
    body['text_split_method'] = 'cut5';
    body['batch_size'] = 1;
    body['streaming_mode'] = false;

    final response = await _dio.post('tts', data: body);

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType:
          response.headers.value('content-type') ?? 'audio/wav',
    );
  }

  @override
  Future<bool> healthCheck() async {
    // GPT-SoVITS doesn't have a dedicated health endpoint.
    // Try a lightweight GET /control or just GET /tts with no params
    // which will return 400 but prove the server is up.
    try {
      final response = await _dio.get(
        'control',
        queryParameters: {'command': ''},
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      // Any response < 500 means server is alive
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
    // GPT-SoVITS doesn't expose a speakers list endpoint.
    // Speakers are defined by reference audio files rather than preset names.
    return [];
  }
}
