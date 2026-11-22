/// Feature badge keys. Keep them stable: they are persisted in v34 tables.
abstract final class AiFeature {
  // tts
  static const presetVoices = 'presetVoices';
  static const instructions = 'instructions';
  static const streamingOutput = 'streamingOutput';
  static const cloudClone = 'cloudClone';
  static const zeroShotClone = 'zeroShotClone';
  // stt
  static const fileTranscription = 'fileTranscription';
  static const streamingTranscription = 'streamingTranscription';
  static const wordTimestamps = 'wordTimestamps';
  static const diarization = 'diarization';
  static const languageDetection = 'languageDetection';
  static const keywords = 'keywords';
  // realtime / translate
  static const audioOutput = 'audioOutput';
  static const textOutput = 'textOutput';
  static const toolCalls = 'toolCalls';
  static const serverVad = 'serverVad';
  static const inputTranscription = 'inputTranscription';
  static const sourceTranscript = 'sourceTranscript';
  // llm
  static const structuredOutput = 'structuredOutput';
  static const reasoning = 'reasoning';
  // vc / vad
  static const zeroShot = 'zeroShot';
  static const local = 'local';
}
