import 'package:neiroha/domain/ai/ai.dart';

const _context = 1048576;
const _inputs = {
  Modality.text,
  Modality.image,
  Modality.audio,
  Modality.video,
  Modality.pdf,
};

/// Text model with thinking levels and defaults from the Gemini thinking
/// docs (read 2026-11-22). Thinking cannot be switched fully off on
/// Gemini 3+; `minimal` is "near-off" and not offered on 3.8 Flash / 4.
ModelDescriptor _llm(
  String id,
  List<ReasoningEffort> levels,
  ReasoningEffort defaultLevel, {
  int maxOut = 65536,
  bool isDefault = false,
}) => ModelDescriptor(
  id: id,
  capability: AiCapability.llm,
  protocol: AiProtocol.geminiGenerateContent,
  features: const {
    AiFeature.structuredOutput,
    AiFeature.toolCalls,
    AiFeature.reasoning,
  },
  isDefault: isDefault,
  llm: LlmTraits(
    inputs: _inputs,
    outputs: const {Modality.text},
    tools: true,
    parallelTools: true,
    structuredOutput: true,
    reasoning: ReasoningSpec(levels: levels, defaultLevel: defaultLevel),
    contextWindow: _context,
    maxOutputTokens: maxOut,
  ),
);

const _lmh = [
  ReasoningEffort.low,
  ReasoningEffort.medium,
  ReasoningEffort.high,
];
const _lmhx = [..._lmh, ReasoningEffort.xhigh];
const _mlmh = [ReasoningEffort.minimal, ..._lmh];

const _live = {
  AiFeature.audioOutput,
  AiFeature.textOutput,
  AiFeature.toolCalls,
  AiFeature.serverVad,
  AiFeature.inputTranscription,
};

/// Google AI Studio models beyond TTS: native generateContent text models,
/// Interactions transcription and Live (conversation, streaming
/// transcription, translation). Names checked against `GET v1beta/models`.
final List<ModelDescriptor> geminiCatalog = [
  _llm('gemini-3.8-flash', _lmh, ReasoningEffort.medium, isDefault: true),
  _llm('gemini-4-hydrogen', _lmhx, ReasoningEffort.high),
  _llm('gemini-4-neon', _lmhx, ReasoningEffort.high),
  _llm('gemini-4-argon', _lmh, ReasoningEffort.medium, maxOut: 32768),
  _llm('gemini-4-carbon', _lmh, ReasoningEffort.medium, maxOut: 32768),
  _llm('gemini-3.6-flash', _mlmh, ReasoningEffort.medium),
  _llm('gemini-3.5-flash-lite', _mlmh, ReasoningEffort.minimal),
  _llm('gemini-3.1-flash-lite', _mlmh, ReasoningEffort.minimal),
  const ModelDescriptor(
    id: 'gemini-3.5-transcribe',
    capability: AiCapability.stt,
    protocol: AiProtocol.geminiInteractions,
    features: {
      AiFeature.fileTranscription,
      AiFeature.wordTimestamps,
      AiFeature.diarization,
      AiFeature.keywords,
      AiFeature.languageDetection,
    },
    isDefault: true,
  ),
  const ModelDescriptor(
    id: 'gemini-3.5-transcribe-live',
    capability: AiCapability.stt,
    protocol: AiProtocol.geminiLive,
    features: {AiFeature.streamingTranscription, AiFeature.keywords},
    platforms: nativePlatforms,
  ),
  const ModelDescriptor(
    id: 'gemini-3.8-live',
    capability: AiCapability.realtime,
    protocol: AiProtocol.geminiLive,
    features: _live,
    platforms: nativePlatforms,
    isDefault: true,
  ),
  const ModelDescriptor(
    id: 'gemini-3.8-live-extended-thinking',
    capability: AiCapability.realtime,
    protocol: AiProtocol.geminiLive,
    features: {..._live, AiFeature.reasoning},
    platforms: nativePlatforms,
  ),
  const ModelDescriptor(
    id: 'gemini-3.1-flash-live-preview',
    capability: AiCapability.realtime,
    protocol: AiProtocol.geminiLive,
    features: _live,
    platforms: nativePlatforms,
    lifecycle: ModelLifecycle.preview,
  ),
  const ModelDescriptor(
    id: 'gemini-3.5-live-translate-preview',
    capability: AiCapability.translate,
    protocol: AiProtocol.geminiLive,
    features: {AiFeature.audioOutput, AiFeature.sourceTranscript},
    platforms: nativePlatforms,
    lifecycle: ModelLifecycle.preview,
    isDefault: true,
  ),
  ..._lyria,
];

const _song = {
  AiFeature.vocals,
  AiFeature.imagePrompt,
  AiFeature.losslessOutput,
};

/// Lyria song models (Interactions API, checked 2026-11-22): full songs
/// with sung lyrics up to a few minutes, or fixed 30 s clips (MP3 only).
/// `lyria-realtime-exp` streams instrumentals over Live and is not mounted.
const _lyria = [
  ModelDescriptor(
    id: 'lyria-3.5',
    capability: AiCapability.music,
    protocol: AiProtocol.geminiInteractions,
    displayName: 'Lyria 3.5',
    features: _song,
    isDefault: true,
  ),
  ModelDescriptor(
    id: 'lyria-3-pro-preview',
    capability: AiCapability.music,
    protocol: AiProtocol.geminiInteractions,
    displayName: 'Lyria 3 Pro',
    features: _song,
    lifecycle: ModelLifecycle.preview,
  ),
  ModelDescriptor(
    id: 'lyria-3-clip-preview',
    capability: AiCapability.music,
    protocol: AiProtocol.geminiInteractions,
    displayName: 'Lyria 3 Clip (30 s)',
    features: {AiFeature.vocals, AiFeature.timedLyrics, AiFeature.imagePrompt},
    lifecycle: ModelLifecycle.preview,
  ),
];
