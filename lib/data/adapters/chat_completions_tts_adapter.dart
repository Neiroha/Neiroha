import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'tts_adapter.dart';

/// Adapter for TTS providers that use the Chat Completions API format.
/// The text to synthesize goes in the `assistant` role message.
/// Audio is returned as base64 in `choices[0].message.audio.data`.
///
/// Compatible providers: MiMo TTS (https://api.xiaomimimo.com/v1)
class ChatCompletionsTtsAdapter extends TtsAdapter {
  final String baseUrl;
  final String apiKey;
  final String modelName;
  final String apiKeyHeader; // MiMo uses 'api-key', others use 'Authorization'
  late final Dio _dio;

  ChatCompletionsTtsAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.modelName,
    this.apiKeyHeader = 'api-key', // MiMo-style
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      headers: {
        apiKeyHeader: apiKeyHeader == 'Authorization'
            ? 'Bearer $apiKey'
            : apiKey,
        'Content-Type': 'application/json',
      },
    ));
  }

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final response = await _dio.post(
      'chat/completions',
      data: {
        'model': modelName,
        'messages': [
          // Optional user message for context / style influence
          if (request.voiceInstruction != null &&
              request.voiceInstruction!.isNotEmpty)
            {'role': 'user', 'content': request.voiceInstruction},
          // The text to synthesize goes in the assistant message
          {'role': 'assistant', 'content': request.text},
        ],
        'audio': {
          'format': request.responseFormat ?? 'wav',
          'voice': request.presetVoiceName ?? 'mimo_default',
        },
      },
    );

    final data = response.data as Map<String, dynamic>;
    final audioData =
        data['choices'][0]['message']['audio']['data'] as String;
    final audioBytes = base64Decode(audioData);

    return TtsResult(
      audioBytes: Uint8List.fromList(audioBytes),
      contentType: 'audio/wav',
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
}
