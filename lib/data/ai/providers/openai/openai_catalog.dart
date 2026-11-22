import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

const _speechShutdown = OpenAiTtsAdapter.speechApiShutdown; // 2027-01-06
const _sttShutdown = '2027-02-26';

ModelDescriptor _m(
  String id,
  AiCapability cap,
  AiProtocol protocol, {
  String name = '',
  Set<String> features = const {},
  Set<AiPlatform> platforms = allPlatforms,
  ModelLifecycle lifecycle = ModelLifecycle.ga,
  String? shutdownAt,
  String? replacement,
  bool isDefault = false,
}) => ModelDescriptor(
  id: id,
  capability: cap,
  protocol: protocol,
  displayName: name,
  features: features,
  platforms: platforms,
  lifecycle: shutdownAt != null ? ModelLifecycle.deprecated : lifecycle,
  shutdownAt: shutdownAt,
  replacement: replacement,
  isDefault: isDefault,
);

const _llm = {AiFeature.structuredOutput, AiFeature.toolCalls};
const _llmReasoning = {..._llm, AiFeature.reasoning};
const _speech = {
  AiFeature.presetVoices,
  AiFeature.instructions,
  AiFeature.streamingOutput,
};
const _realtimeTts = {..._speech};
const _realtime = {
  AiFeature.audioOutput,
  AiFeature.textOutput,
  AiFeature.toolCalls,
  AiFeature.serverVad,
  AiFeature.inputTranscription,
};

/// OpenAI official API. One key provides every capability below.
final List<ModelDescriptor> openAiCatalog = [
  // LLM — Responses API.
  for (final (id, isDefault) in const [
    ('gpt-6-luna', true),
    ('gpt-6-sol', false),
    ('gpt-6.2-sol', false),
    ('gpt-5.5', false),
    ('gpt-5.4-mini', false),
    ('gpt-5.4-nano', false),
  ])
    _m(
      id,
      AiCapability.llm,
      AiProtocol.openAiResponses,
      features: _llmReasoning,
      isDefault: isDefault,
    ),
  // TTS — Realtime models replace the Speech API.
  _m(
    'gpt-realtime-2.1-mini',
    AiCapability.tts,
    AiProtocol.openAiRealtime,
    features: _realtimeTts,
    platforms: nativePlatforms,
    isDefault: true,
  ),
  _m(
    'gpt-realtime-2.1',
    AiCapability.tts,
    AiProtocol.openAiRealtime,
    features: _realtimeTts,
    platforms: nativePlatforms,
  ),
  for (final id in const ['gpt-4o-mini-tts', 'tts-1-hd', 'tts-1'])
    _m(
      id,
      AiCapability.tts,
      AiProtocol.openAiSpeech,
      features: id.startsWith('tts-1')
          ? const {AiFeature.presetVoices, AiFeature.streamingOutput}
          : _speech,
      shutdownAt: _speechShutdown,
      replacement: 'gpt-realtime-2.1-mini',
    ),
  // STT — file transcription.
  _m(
    'gpt-transcribe',
    AiCapability.stt,
    AiProtocol.openAiTranscription,
    features: const {
      AiFeature.fileTranscription,
      AiFeature.streamingTranscription,
      AiFeature.languageDetection,
      AiFeature.keywords,
    },
    isDefault: true,
  ),
  _m(
    'gpt-live-transcribe',
    AiCapability.stt,
    AiProtocol.openAiRealtimeTranscription,
    name: 'GPT Live Transcribe (streaming)',
    features: const {AiFeature.streamingTranscription},
    platforms: nativePlatforms,
  ),
  _m(
    'gpt-realtime-whisper',
    AiCapability.stt,
    AiProtocol.openAiRealtimeTranscription,
    features: const {AiFeature.streamingTranscription},
    platforms: nativePlatforms,
  ),
  _m(
    'gpt-4o-transcribe-diarize',
    AiCapability.stt,
    AiProtocol.openAiTranscription,
    features: const {AiFeature.fileTranscription, AiFeature.diarization},
    shutdownAt: _sttShutdown,
    replacement: 'gpt-transcribe',
  ),
  _m(
    'whisper-1',
    AiCapability.stt,
    AiProtocol.openAiTranscription,
    features: const {
      AiFeature.fileTranscription,
      AiFeature.wordTimestamps,
      AiFeature.languageDetection,
    },
    shutdownAt: _sttShutdown,
    replacement: 'gpt-transcribe',
  ),
  // Realtime conversation.
  for (final (id, isDefault) in const [
    ('gpt-realtime-2.1', true),
    ('gpt-realtime-2.1-mini', false),
    ('gpt-realtime-2', false),
  ])
    _m(
      id,
      AiCapability.realtime,
      AiProtocol.openAiRealtime,
      features: _realtime,
      platforms: nativePlatforms,
      isDefault: isDefault,
    ),
  // Speech translation.
  _m(
    'gpt-realtime-translate',
    AiCapability.translate,
    AiProtocol.openAiRealtimeTranslation,
    features: const {AiFeature.audioOutput, AiFeature.sourceTranscript},
    platforms: nativePlatforms,
    isDefault: true,
  ),
];
