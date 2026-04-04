enum AdapterType {
  openaiCompatible,
  gptSovits,
  qwen3Native,
  cosyvoice;

  String get displayName => switch (this) {
        openaiCompatible => 'OpenAI Compatible',
        gptSovits => 'GPT-SoVITS',
        qwen3Native => 'Qwen3 Native',
        cosyvoice => 'CosyVoice',
      };
}
