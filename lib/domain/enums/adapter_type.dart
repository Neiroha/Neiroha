enum AdapterType {
  openaiCompatible,
  gptSovits,
  cosyvoice,
  voxcpm2Native,
  chatCompletionsTts,
  azureTts,
  systemTts,
  geminiTts,
  elevenLabs,
  minimaxTts,
  indexTts;

  String get displayName => switch (this) {
    openaiCompatible => 'OpenAI TTS API Compatible',
    gptSovits => 'GPT-SoVITS',
    cosyvoice => 'CosyVoice Native',
    voxcpm2Native => 'VoxCPM2 Native',
    chatCompletionsTts => 'OpenAI Chat Completions TTS',
    azureTts => 'Azure Speech Service',
    systemTts => 'Windows System TTS',
    geminiTts => 'Google Gemini TTS',
    elevenLabs => 'ElevenLabs',
    minimaxTts => 'MiniMax Speech',
    indexTts => 'IndexTTS 2.5 (WebUI)',
  };

  String get defaultModel => switch (this) {
    openaiCompatible => 'tts-1',
    gptSovits => 'default',
    cosyvoice => 'default',
    voxcpm2Native => 'default',
    chatCompletionsTts => 'mimo-v2-tts',
    azureTts => '',
    systemTts => '',
    geminiTts => 'gemini-3.8-flash-tts',
    elevenLabs => 'eleven_v4',
    minimaxTts => 'speech-2.8-hd',
    indexTts => 'auto',
  };

  /// Whether this adapter type fetches models (synthesis engines) from the API.
  bool get supportsModelQuery => switch (this) {
    openaiCompatible => true,
    chatCompletionsTts => true,
    gptSovits => true,
    // Gemini / MiniMax publish no model-list endpoint for TTS — the
    // adapters return a curated list so the picker UI still shows them.
    geminiTts => true,
    elevenLabs => true,
    minimaxTts => true,
    _ => false,
  };

  /// Whether this adapter type fetches voices (speaker identities) from the API.
  bool get supportsVoiceQuery => switch (this) {
    azureTts => true,
    systemTts => true,
    openaiCompatible => true,
    chatCompletionsTts => true,
    gptSovits => true,
    geminiTts => true,
    elevenLabs => true,
    minimaxTts => true,
    _ => false,
  };

  /// Whether this adapter type has BOTH a model concept AND a separate voice
  /// concept (e.g. OpenAI TTS: model=tts-1, voice=alloy).
  /// When true the provider screen and character dialog show separate sections.
  bool get hasSeparateModelAndVoice => switch (this) {
    openaiCompatible => true,
    chatCompletionsTts => true,
    gptSovits => true,
    geminiTts => true,
    elevenLabs => true,
    minimaxTts => true,
    _ => false,
  };

  /// Whether the upstream can register a reusable cloned voice from a
  /// reference recording (see `VoiceCloneCapable`).
  bool get supportsCloudVoiceClone => switch (this) {
    elevenLabs => true,
    minimaxTts => true,
    _ => false,
  };

  /// Zero-shot engines that clone from the character's reference audio on
  /// every request (no preset voices).
  bool get requiresReferenceAudio => switch (this) {
    indexTts => true,
    _ => false,
  };

  /// Whether to show the default model name field in the provider editor.
  bool get showDefaultModelField => switch (this) {
    openaiCompatible => false,
    chatCompletionsTts => false,
    azureTts => false,
    systemTts => false,
    geminiTts => false,
    elevenLabs => false,
    minimaxTts => false,
    _ => true,
  };
}
