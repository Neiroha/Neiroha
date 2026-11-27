import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/speech_synthesizer.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

/// Speech API or Realtime-as-TTS, chosen by the descriptor's protocol.
class OpenAiSpeechSynthesizer implements SpeechSynthesizer {
  OpenAiSpeechSynthesizer(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final OpenAiEndpoint endpoint;

  late final adapter = OpenAiTtsAdapter(
    baseUrl: endpoint.baseUrl,
    apiKey: endpoint.apiKey,
    modelName: descriptor.id,
    explicitRoute: descriptor.protocol == AiProtocol.openAiRealtime
        ? ServiceRoute.realtime
        : ServiceRoute.speech,
  );

  @override
  Stream<TtsEvent> synthesize(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) => adapter.synthesizeStream(request, cancellation: cancellation);

  @override
  Future<List<String>> voices() async =>
      OpenAiTtsAdapter.voicesForModel(descriptor.id);
}
