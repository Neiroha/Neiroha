/// What a model can be used for. One model may be listed under several
/// capabilities (e.g. a Realtime model serves both `realtime` and `tts`).
enum AiCapability { llm, tts, stt, realtime, translate, vc, vad }

/// Wire protocol a model mount uses. Several providers share one protocol.
enum AiProtocol {
  openAiChat,
  openAiResponses,
  openAiSpeech,
  openAiRealtime,
  openAiTranscription,
  openAiRealtimeTranscription,
  openAiRealtimeTranslation,
  geminiGenerateContent,
  geminiInteractions,
  geminiLive,
  elevenLabs,
  native,
  onDevice,
}

enum AiPlatform { desktop, web, android }

const allPlatforms = {AiPlatform.desktop, AiPlatform.web, AiPlatform.android};
const nativePlatforms = {AiPlatform.desktop, AiPlatform.android};
