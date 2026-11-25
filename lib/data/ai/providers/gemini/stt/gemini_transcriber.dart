import 'dart:convert';

import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import '../gemini_endpoint.dart';

/// `gemini-3.5-transcribe` over the Interactions API: no prompt, audio in,
/// verbatim text out. Word timestamps and speaker diarization map onto
/// `transcription_config.mode`; keywords onto `custom_vocabulary` (which the
/// service does not combine with either).
class GeminiTranscriber implements Transcriber {
  GeminiTranscriber(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;

  static Map<String, Object?> body(
    String model,
    AudioInput audio,
    TranscribeOptions options,
  ) {
    final detailed = options.wordTimestamps || options.diarize;
    return {
      'model': model,
      'input': [
        {
          'type': 'user_input',
          'content': [
            {
              'type': 'audio',
              'data': base64Encode(audio.bytes),
              'mime_type': audio.contentType,
            },
          ],
        },
      ],
      'generation_config': {
        'transcription_config': {
          if (options.languages.isNotEmpty) 'language_codes': options.languages,
          if (!detailed && options.keywords.isNotEmpty)
            'custom_vocabulary': options.keywords.take(1000).toList(),
          if (detailed)
            'mode': {
              'type': 'verbatim',
              if (options.diarize) 'diarization_mode': 'speaker',
              if (options.wordTimestamps) 'timestamp_granularities': ['word'],
            },
        },
      },
    };
  }

  static Duration? _offset(Object? raw) {
    final m = RegExp(r'^([\d.]+)s$').firstMatch('$raw');
    if (m == null) return null;
    return Duration(microseconds: (double.parse(m[1]!) * 1e6).round());
  }

  static Transcript parse(Object? data, List<String> languages) {
    if (data is! Map) {
      throw const AiProviderException('Gemini returned no JSON body.');
    }
    final text = StringBuffer();
    final words = <TranscriptWord>[];
    for (final step in (data['steps'] as List? ?? const []).whereType<Map>()) {
      if (step['type'] != 'model_output') continue;
      for (final c in (step['content'] as List? ?? const []).whereType<Map>()) {
        if (c['type'] != 'text' || c['text'] is! String) continue;
        text.write(c['text']);
        for (final a
            in (c['annotations'] as List? ?? const []).whereType<Map>()) {
          final start = _offset(a['start_offset']);
          final end = _offset(a['end_offset']);
          if (a['type'] == 'word_info' && start != null && end != null) {
            words.add(
              TranscriptWord(
                '${a['text'] ?? ''}',
                start,
                end,
                speaker: a['speaker'] == null ? null : '${a['speaker']}',
              ),
            );
          }
        }
      }
    }
    return Transcript(
      text.toString().trim(),
      languages: languages,
      words: words,
      raw: Map<String, Object?>.from(data),
    );
  }

  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, endpoint.apiKey, (token) async {
    final response = await endpoint.dio().post<dynamic>(
      'interactions',
      data: body(descriptor.id, audio, options),
      cancelToken: token,
    );
    return parse(response.data, options.languages);
  });
}
