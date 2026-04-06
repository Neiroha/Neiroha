import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for CosyVoice native API.
///
/// Endpoints used:
///   GET  /health              — health check
///   GET  /speakers            — list available speakers
///   GET  /cosyvoice/profiles  — list local profiles
///   POST /cosyvoice/speech    — JSON-body synthesis
///   POST /cosyvoice/speech/upload — multipart synthesis with uploaded audio
class CosyVoiceAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  late final Dio _dio;

  CosyVoiceAdapter({
    required this.baseUrl,
    required this.apiKey,
    this.modelName = 'cosyvoice',
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
    // If we have a local ref audio file, use the multipart upload endpoint
    if (request.refAudioPath != null && request.refAudioPath!.isNotEmpty) {
      return _synthesizeWithUpload(request);
    }
    return _synthesizeJson(request);
  }

  /// POST /cosyvoice/speech — JSON body (preset voice, instruct, cross_lingual)
  Future<TtsResult> _synthesizeJson(TtsRequest request) async {
    final body = <String, dynamic>{
      'text': request.text,
      'speed': request.speed,
      'response_format': request.responseFormat ?? 'wav',
    };

    // Determine mode from request fields
    if (request.voiceInstruction != null &&
        request.voiceInstruction!.isNotEmpty) {
      body['mode'] = 'instruct';
      body['instruct_text'] = request.voiceInstruction;
    }

    // Profile / speaker name
    if (request.presetVoiceName != null &&
        request.presetVoiceName!.isNotEmpty) {
      body['profile'] = request.presetVoiceName;
    }

    if (request.promptText != null && request.promptText!.isNotEmpty) {
      body['prompt_text'] = request.promptText;
    }

    if (request.promptLang != null && request.promptLang!.isNotEmpty) {
      body['prompt_lang'] = request.promptLang;
    }

    final response = await _dio.post('cosyvoice/speech', data: body);

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/wav',
    );
  }

  /// POST /cosyvoice/speech/upload — multipart with prompt_audio file
  Future<TtsResult> _synthesizeWithUpload(TtsRequest request) async {
    final file = File(request.refAudioPath!);
    final fileName = file.path.split(Platform.pathSeparator).last;

    final formData = FormData.fromMap({
      'text': request.text,
      'mode': 'zero_shot',
      'speed': request.speed,
      'response_format': request.responseFormat ?? 'wav',
      'prompt_audio': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      if (request.promptText != null && request.promptText!.isNotEmpty)
        'prompt_text': request.promptText,
      if (request.promptLang != null && request.promptLang!.isNotEmpty)
        'prompt_lang': request.promptLang,
      if (request.presetVoiceName != null &&
          request.presetVoiceName!.isNotEmpty)
        'profile': request.presetVoiceName,
      if (request.voiceInstruction != null &&
          request.voiceInstruction!.isNotEmpty)
        'instruct_text': request.voiceInstruction,
    });

    final response = await _dio.post(
      'cosyvoice/speech/upload',
      data: formData,
    );

    return TtsResult(
      audioBytes: Uint8List.fromList(response.data as List<int>),
      contentType: response.headers.value('content-type') ?? 'audio/wav',
    );
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        'health',
        options: Options(responseType: ResponseType.json),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getSpeakers() async {
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
