import 'package:neiroha/data/ai/providers/openai/llm/openai_language_model.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/providers/openai/realtime/openai_realtime_model.dart';
import 'package:neiroha/data/ai/providers/openai/stt/openai_streaming_transcriber.dart';
import 'package:neiroha/data/ai/providers/openai/stt/openai_transcriber.dart';
import 'package:neiroha/data/ai/providers/openai/translate/openai_speech_translator.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_speech_synthesizer.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

/// Opens an OpenAI-protocol model for [descriptor].
CapabilityModel? openOpenAiModel(
  ModelDescriptor descriptor,
  OpenAiEndpoint endpoint,
) => switch (descriptor.protocol) {
  AiProtocol.openAiChat ||
  AiProtocol.openAiResponses => OpenAiLanguageModel(descriptor, endpoint),
  AiProtocol.openAiSpeech => OpenAiSpeechSynthesizer(descriptor, endpoint),
  AiProtocol.openAiRealtime when descriptor.capability == AiCapability.tts =>
    OpenAiSpeechSynthesizer(descriptor, endpoint),
  AiProtocol.openAiRealtime => OpenAiRealtimeModel(descriptor, endpoint),
  AiProtocol.openAiTranscription
      when descriptor.has(AiFeature.streamingTranscription) =>
    OpenAiDualTranscriber(descriptor, endpoint),
  AiProtocol.openAiTranscription => OpenAiTranscriber(descriptor, endpoint),
  AiProtocol.openAiRealtimeTranscription => OpenAiStreamingTranscriber(
    descriptor,
    endpoint,
  ),
  AiProtocol.openAiRealtimeTranslation => OpenAiSpeechTranslator(
    descriptor,
    endpoint,
  ),
  _ => null,
};
