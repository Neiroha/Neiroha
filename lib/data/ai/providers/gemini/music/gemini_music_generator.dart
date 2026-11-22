import 'dart:convert';

import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import '../gemini_endpoint.dart';
import 'lyria_lyrics.dart';

/// Lyria song generation over the Interactions API (`lyria-3.5`,
/// `lyria-3-pro-preview`, `lyria-3-clip-preview`). Audio is 44.1 kHz
/// stereo with a SynthID watermark; lyrics come back as a text step.
class GeminiMusicGenerator implements MusicGenerator {
  GeminiMusicGenerator(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;

  static String promptText(MusicRequest r) {
    final lyrics = r.lyrics.trim();
    return [
      r.prompt.trim(),
      if (r.instrumental) 'Instrumental only, no vocals.',
      if (!r.instrumental && lyrics.isNotEmpty) 'Lyrics:\n$lyrics',
    ].where((s) => s.isNotEmpty).join('\n\n');
  }

  Map<String, Object?> body(MusicRequest r) {
    final text = promptText(r);
    final images = descriptor.features.contains(AiFeature.imagePrompt)
        ? r.images
        : const <Never>[];
    return {
      'model': descriptor.id,
      'input': images.isEmpty
          ? text
          : [
              {'type': 'text', 'text': text},
              for (final (bytes, mime) in images.take(10))
                {
                  'type': 'image',
                  'mime_type': mime,
                  'data': base64Encode(bytes),
                },
            ],
      if (r.lossless && descriptor.features.contains(AiFeature.losslessOutput))
        'response_format': {'type': 'audio', 'mime_type': 'audio/wav'},
    };
  }

  static GeneratedSong parse(Object? data) {
    if (data is! Map) {
      throw const AiProviderException('Lyria returned no JSON body.');
    }
    final text = StringBuffer();
    String? audio, mime;
    for (final step in (data['steps'] as List? ?? const []).whereType<Map>()) {
      if (step['type'] != 'model_output') continue;
      for (final c in (step['content'] as List? ?? const []).whereType<Map>()) {
        if (c['type'] == 'text' && c['text'] is String) {
          text.writeln(c['text']);
        } else if (c['type'] == 'audio' && c['data'] is String) {
          audio = c['data'] as String;
          mime = c['mime_type'] as String?;
        }
      }
    }
    if (audio == null) {
      throw AiProviderException(
        'Lyria returned no audio (${data['status'] ?? 'unknown status'}).',
      );
    }
    final raw = text.toString().trim();
    final usage = data['usage'];
    return GeneratedSong(
      audio: base64Decode(audio),
      mimeType: mime ?? 'audio/mpeg',
      lyrics: parseLyriaLyrics(raw),
      rawLyrics: raw,
      usage: usage is Map ? Map<String, Object?>.from(usage) : const {},
    );
  }

  @override
  Future<GeneratedSong> compose(
    MusicRequest request, {
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, endpoint.apiKey, (token) async {
    final response = await endpoint
        .dio(timeout: const Duration(minutes: 10))
        .post<dynamic>('interactions', data: body(request), cancelToken: token);
    return parse(response.data);
  });
}
