import 'dart:async';

import 'package:neiroha/data/ai/protocols/realtime/openai_transcription_session.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/ai/models/transcriber.dart';

class OpenAiStreamingTranscriber implements StreamingTranscriber {
  OpenAiStreamingTranscriber(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  @override
  Future<AudioStreamSession> open({
    TranscribeOptions options = const TranscribeOptions(),
  }) => OpenAiTranscriptionSession.connect(
    baseUrl: endpoint.baseUrl,
    apiKey: endpoint.apiKey,
    model: descriptor.id,
    options: options,
  );
}
