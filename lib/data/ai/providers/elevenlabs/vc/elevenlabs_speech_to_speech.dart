import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_connection.dart';
import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/voice_converter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

/// POST `/v1/speech-to-speech/{voice_id}` (multipart `audio`, `model_id`).
class ElevenLabsSpeechToSpeech implements VoiceConverter {
  ElevenLabsSpeechToSpeech(this.descriptor, this.connection);
  @override
  final ModelDescriptor descriptor;
  final ElevenLabsConnection connection;

  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) => withCancel(cancellation, connection.config.apiKey, (token) async {
    final voice = Uri.encodeComponent(targetVoice.trim());
    if (voice.isEmpty) throw const AiProviderException('Pick a target voice.');
    final response = await connection.dio.post<List<int>>(
      'v1/speech-to-speech/$voice',
      queryParameters: {'output_format': 'mp3_44100_128'},
      data: FormData()
        ..files.add(MapEntry('audio', elevenLabsAudioFile(audio)))
        ..fields.add(MapEntry('model_id', descriptor.id)),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: token,
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    if (bytes.isEmpty) throw const AiProviderException('VC returned no audio.');
    return TtsResult(audioBytes: bytes, contentType: 'audio/mpeg');
  });
}
