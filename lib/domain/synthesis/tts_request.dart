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

  /// Voice character this line is spoken by. Lets the synthesis service run
  /// the character's processing chain (translate → TTS → voice conversion).
  final String? voiceAssetId;

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
    this.voiceAssetId,
  });

  /// Same request with [text] replaced (after a chain's text steps).
  TtsRequest withText(String text) => _copy(text, responseFormat);

  /// Same request asking for [format] (`pcm`, `wav`, …).
  TtsRequest withFormat(String format) => _copy(text, format);

  /// Same request asking for a whole file instead of streamed raw PCM.
  TtsRequest asWholeFile() =>
      responseFormat == 'pcm' ? _copy(text, null) : this;

  TtsRequest _copy(String text, String? format) => TtsRequest(
    text: text,
    voice: voice,
    speed: speed,
    responseFormat: format,
    refAudioPath: refAudioPath,
    promptText: promptText,
    promptLang: promptLang,
    textLang: textLang,
    voiceInstruction: voiceInstruction,
    presetVoiceName: presetVoiceName,
    voiceClonePromptBase64: voiceClonePromptBase64,
    audioTagPrefix: audioTagPrefix,
    voiceAssetId: voiceAssetId,
  );
}

/// Result of a TTS synthesis call.
class TtsResult {
  final Uint8List audioBytes;
  final String contentType;

  const TtsResult({required this.audioBytes, required this.contentType});
}
