enum AdapterType {
  openaiCompatible,
  gptSovits,
  cosyvoice,
  voxcpm2Native,
  chatCompletionsTts,
  azureTts,
  systemTts,
  geminiTts;

  String get displayName => switch (this) {
        openaiCompatible => 'OpenAI TTS API Compatible',
        gptSovits => 'GPT-SoVITS',
        cosyvoice => 'CosyVoice Native',
        voxcpm2Native => 'VoxCPM2 Native',
        chatCompletionsTts => 'OpenAI Chat Completions TTS',
        azureTts => 'Azure Speech Service',
        systemTts => 'Windows System TTS',
        geminiTts => 'Google Gemini TTS',
      };

  String get defaultModel => switch (this) {
        openaiCompatible => 'tts-1',
        gptSovits => 'gpt-sovits',
        cosyvoice => '',
        voxcpm2Native => 'voxcpm2',
        chatCompletionsTts => 'mimo-v2-tts',
        azureTts => '',
        systemTts => '',
        geminiTts => 'gemini-2.5-flash-preview-tts',
      };

  /// Whether this adapter type fetches models (synthesis engines) from the API.
  bool get supportsModelQuery => switch (this) {
        openaiCompatible => true,
        chatCompletionsTts => true,
        // Gemini has only 2 free TTS models — the adapter returns them from
        // a hard-coded list, so we still want the picker UI to show them.
        geminiTts => true,
        _ => false,
      };

  /// Whether this adapter type fetches voices (speaker identities) from the API.
  bool get supportsVoiceQuery => switch (this) {
        azureTts => true,
        systemTts => true,
        openaiCompatible => true,
        chatCompletionsTts => true,
        geminiTts => true,
        _ => false,
      };

  /// Whether this adapter type has BOTH a model concept AND a separate voice
  /// concept (e.g. OpenAI TTS: model=tts-1, voice=alloy).
  /// When true the provider screen and character dialog show separate sections.
  bool get hasSeparateModelAndVoice => switch (this) {
        openaiCompatible => true,
        chatCompletionsTts => true,
        geminiTts => true,
        _ => false,
      };

  /// Whether to show the default model name field in the provider editor.
  bool get showDefaultModelField => switch (this) {
        openaiCompatible => false,
        chatCompletionsTts => false,
        azureTts => false,
        systemTts => false,
        geminiTts => false,
        _ => true,
      };
}
