enum TaskMode {
  presetVoice,
  cloneWithPrompt,
  voiceDesign;

  String get displayName => switch (this) {
    presetVoice => 'Preset Voice',
    cloneWithPrompt => 'Clone with Prompt',
    voiceDesign => 'Voice Design',
  };
}
