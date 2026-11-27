import 'dart:async';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// POST `audio/transcriptions` (multipart). `gpt-transcribe` takes
/// `languages[]`; `whisper-1` alone supports word timestamps.
Future<Transcript> openAiTranscribe(
  Dio dio, {
  required String apiKey,
  required String model,
  required AudioInput audio,
  TranscribeOptions options = const TranscribeOptions(),
  TtsCancelToken? cancellation,
  String path = 'audio/transcriptions',
}) {
  final legacyLanguage = model == 'whisper-1' || model.startsWith('gpt-4o');
  final verbose = options.wordTimestamps && model == 'whisper-1';
  final diarized = options.diarize && model.contains('diarize');
  final form = FormData()
    ..files.add(
      MapEntry(
        'file',
        MultipartFile.fromBytes(
          audio.bytes,
          filename: audio.fileName,
          contentType: DioMediaType.parse(audio.contentType),
        ),
      ),
    )
    ..fields.add(MapEntry('model', model));
  if (verbose) {
    form.fields
      ..add(const MapEntry('response_format', 'verbose_json'))
      ..add(const MapEntry('timestamp_granularities[]', 'word'));
  } else if (diarized) {
    form.fields
      ..add(const MapEntry('response_format', 'diarized_json'))
      ..add(const MapEntry('chunking_strategy', 'auto'));
  }
  if (options.languages.isNotEmpty) {
    if (legacyLanguage) {
      form.fields.add(MapEntry('language', options.languages.first));
    } else {
      for (final code in options.languages) {
        form.fields.add(MapEntry('languages[]', code));
      }
    }
  }
  if (options.prompt?.trim().isNotEmpty == true && !diarized) {
    form.fields.add(MapEntry('prompt', options.prompt!.trim()));
  }
  if (!legacyLanguage) {
    for (final word in options.keywords) {
      form.fields.add(MapEntry('keywords[]', word));
    }
  }
  return withCancel(cancellation, apiKey, (token) async {
    final response = await dio.post<dynamic>(
      path,
      data: form,
      cancelToken: token,
    );
    return parseOpenAiTranscript(response.data);
  });
}

Transcript parseOpenAiTranscript(Object? data) {
  if (data is String) return Transcript(data.trim());
  if (data is! Map) {
    throw const AiProviderException('Transcription returned no JSON.');
  }
  final json = Map<String, Object?>.from(data);
  final languages = <String>[
    if (json['languages'] is List)
      for (final item in json['languages'] as List)
        if (item is Map && item['code'] is String) item['code'] as String,
    if (json['language'] is String) json['language'] as String,
  ];
  Duration secs(Object? v) =>
      Duration(microseconds: ((v as num? ?? 0) * 1e6).round());
  final words = <TranscriptWord>[
    if (json['words'] is List)
      for (final w in (json['words'] as List).whereType<Map>())
        TranscriptWord('${w['word'] ?? ''}', secs(w['start']), secs(w['end'])),
    if (json['segments'] is List && json['words'] is! List)
      for (final s in (json['segments'] as List).whereType<Map>())
        if (s['speaker'] != null)
          TranscriptWord(
            '${s['text'] ?? ''}',
            secs(s['start']),
            secs(s['end']),
            speaker: '${s['speaker']}',
          ),
  ];
  return Transcript(
    '${json['text'] ?? ''}'.trim(),
    languages: languages,
    words: words,
    raw: json,
  );
}
