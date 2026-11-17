import 'dart:typed_data';

/// Request payload for TTS synthesis, unified across all adapters.
class TtsRequest {
  final String text;
  final String voice;
  final double speed;
  final String? responseFormat;

  // GPT-SoVITS specific
  final String? refAudioPath;
  final String? promptText;
  final String? promptLang;
  final String? textLang;

  // Per-call style / direction text for adapters that expose instruction
  // control (MiMo chat-completions TTS, CosyVoice instruct, VoxCPM2, Gemini).
  final String? voiceInstruction;

  // OpenAI-compatible / OpenAI official preset (`voice_…` = custom voice)
  final String? presetVoiceName;

  // MiMo V2.5 VoiceClone: data:audio/mpeg;base64,... or data:audio/wav;base64,...
  final String? voiceClonePromptBase64;

  // Audio tag prefix prepended to text, e.g. "(磁性)" or "(兴奋|颤抖)"
  final String? audioTagPrefix;

  const TtsRequest({
    required this.text,
    required this.voice,
    this.speed = 1.0,
    this.responseFormat,
    this.refAudioPath,
    this.promptText,
    this.promptLang,
    this.textLang,
    this.voiceInstruction,
    this.presetVoiceName,
    this.voiceClonePromptBase64,
    this.audioTagPrefix,
  });
}

/// Result of a TTS synthesis call.
class TtsResult {
  final Uint8List audioBytes;
  final String contentType;

  const TtsResult({required this.audioBytes, required this.contentType});
}
