enum AdapterType {
  openaiCompatible,
  gptSovits,
  qwen3Native,
  cosyvoice,
  chatCompletionsTts;

  String get displayName => switch (this) {
        openaiCompatible => 'OpenAI TTS API Compatible',
        gptSovits => 'GPT-SoVITS',
        qwen3Native => 'Qwen3 Native',
        cosyvoice => 'CosyVoice',
        chatCompletionsTts => 'OpenAI Chat API Completion',
      };

  String get defaultModel => switch (this) {
        openaiCompatible => 'tts-1',
        gptSovits => 'gpt-sovits',
        qwen3Native => 'qwen3-tts',
        cosyvoice => 'cosyvoice',
        chatCompletionsTts => 'mimo-v2-tts',
      };
}
