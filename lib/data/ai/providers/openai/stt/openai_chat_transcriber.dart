import 'dart:convert';

import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// ASR models served over Chat Completions: the audio goes in as an
/// `input_audio` content part and the transcript comes back as the reply
/// (Xiaomi `mimo-v2.5-asr`). Languages and keywords ride along as a short
/// text part, since the protocol has no dedicated fields for them.
class OpenAiChatTranscriber implements Transcriber {
  OpenAiChatTranscriber(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  /// `input_audio.format` for a MIME type (`audio/mpeg` → `mp3`).
  static String formatOf(String contentType) {
    final sub = contentType.split(';').first.split('/').last.toLowerCase();
    return switch (sub) {
      'mpeg' || 'mp3' => 'mp3',
      'x-wav' || 'wave' || 'wav' => 'wav',
      'x-m4a' || 'mp4' => 'm4a',
      _ => sub,
    };
  }

  static Map<String, Object?> body(
    String model,
    AudioInput audio,
    TranscribeOptions options,
  ) {
    final hints = [
      if (options.languages.isNotEmpty)
        'Language: ${options.languages.join(', ')}.',
      if (options.keywords.isNotEmpty)
        'Vocabulary: ${options.keywords.join(', ')}.',
    ].join(' ');
    return {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            if (hints.isNotEmpty) {'type': 'text', 'text': hints},
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Encode(audio.bytes),
                'format': formatOf(audio.contentType),
              },
            },
          ],
        },
      ],
    };
  }

  static String parse(Object? data) {
    final choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw const AiProviderException('The ASR model returned no choices.');
    }
    final content = (choices.first as Map)['message']?['content'];
    if (content is String) return content.trim();
    if (content is List) {
      return [
        for (final p in content.whereType<Map>())
          if (p['text'] is String) p['text'] as String,
      ].join().trim();
    }
    return '';
  }

  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, endpoint.apiKey, (token) async {
    final response =
        await openAiDio(
          endpoint.baseUrl,
          endpoint.apiKey,
          apiKeyHeader: endpoint.apiKeyHeader,
        ).post<dynamic>(
          'chat/completions',
          data: body(descriptor.id, audio, options),
          cancelToken: token,
        );
    final data = response.data;
    return Transcript(
      parse(data),
      languages: options.languages,
      raw: data is Map ? Map<String, Object?>.from(data) : const {},
    );
  });
}
