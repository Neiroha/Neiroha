import 'dart:async';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_connection.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/transcriber.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// POST `/v1/speech-to-text` (multipart `file`, `model_id`).
class ElevenLabsScribe implements Transcriber {
  ElevenLabsScribe(this.descriptor, this.connection);
  @override
  final ModelDescriptor descriptor;
  final ElevenLabsConnection connection;

  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, connection.config.apiKey, (token) async {
    final form = FormData()
      ..files.add(MapEntry('file', elevenLabsAudioFile(audio)))
      ..fields.add(MapEntry('model_id', descriptor.id));
    if (options.languages.isNotEmpty) {
      form.fields.add(MapEntry('language_code', options.languages.first));
    }
    if (options.diarize) form.fields.add(const MapEntry('diarize', 'true'));
    if (options.wordTimestamps) {
      form.fields.add(const MapEntry('timestamps_granularity', 'word'));
    }
    final response = await connection.dio.post<dynamic>(
      'v1/speech-to-text',
      data: form,
      cancelToken: token,
    );
    final data = response.data;
    if (data is! Map) {
      throw const AiProviderException('Scribe returned no JSON.');
    }
    Duration secs(Object? v) =>
        Duration(microseconds: ((v as num? ?? 0) * 1e6).round());
    return Transcript(
      '${data['text'] ?? ''}'.trim(),
      languages: [if (data['language_code'] is String) data['language_code']],
      words: [
        for (final w in (data['words'] as List? ?? const []).whereType<Map>())
          if (w['type'] == null || w['type'] == 'word')
            TranscriptWord(
              '${w['text'] ?? ''}',
              secs(w['start']),
              secs(w['end']),
              speaker: w['speaker_id'] as String?,
            ),
      ],
      raw: Map<String, Object?>.from(data),
    );
  });
}
