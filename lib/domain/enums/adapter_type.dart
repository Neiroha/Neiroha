enum AdapterType {
  openaiCompatible,
  gptSovits,
  qwen3Native,
  cosyvoice,
  chatCompletionsTts,
  azureTts,
  systemTts;

  String get displayName => switch (this) {
        openaiCompatible => 'OpenAI TTS API Compatible',
        gptSovits => 'GPT-SoVITS',
        qwen3Native => 'Qwen3 Native',
        cosyvoice => 'CosyVoice Native',
        chatCompletionsTts => 'OpenAI Chat Completions TTS',
        azureTts => 'Azure Speech Service',
        systemTts => 'Windows System TTS',
      };

  String get defaultModel => switch (this) {
        openaiCompatible => 'tts-1',
        gptSovits => 'gpt-sovits',
        qwen3Native => 'qwen3-tts',
        cosyvoice => '',
        chatCompletionsTts => 'mimo-v2-tts',
        azureTts => '',
        systemTts => '',
      };

  /// Whether this adapter type supports querying available models from the API.
  bool get supportsModelQuery => switch (this) {
        openaiCompatible => true,
        chatCompletionsTts => true,
        _ => false,
      };

  /// Whether this adapter type supports querying available voices from the API.
  bool get supportsVoiceQuery => switch (this) {
        azureTts => true,
        systemTts => true,
        _ => false,
      };

  /// Whether to show the default model name field in the provider editor.
  bool get showDefaultModelField => switch (this) {
        openaiCompatible => false,
        chatCompletionsTts => false,
        azureTts => false,
        systemTts => false,
        _ => true,
      };
}
