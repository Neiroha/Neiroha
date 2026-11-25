import 'dart:async';

import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_transcriptions.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/providers/openai/stt/openai_streaming_transcriber.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/ai/models/transcriber.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

class OpenAiTranscriber implements Transcriber {
  OpenAiTranscriber(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) => openAiTranscribe(
    openAiDio(endpoint.baseUrl, endpoint.apiKey),
    apiKey: endpoint.apiKey,
    model: descriptor.id,
    audio: audio,
    options: options,
    cancellation: cancellation,
  );
}

/// `gpt-transcribe` serves both file and live transcription.
class OpenAiDualTranscriber extends OpenAiTranscriber
    implements StreamingTranscriber {
  OpenAiDualTranscriber(super.descriptor, super.endpoint);

  @override
  Future<AudioStreamSession> open({
    TranscribeOptions options = const TranscribeOptions(),
  }) => OpenAiStreamingTranscriber(descriptor, endpoint).open(options: options);
}
