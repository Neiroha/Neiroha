part of 'create_character_dialog.dart';

/// Fields for GPT-SoVITS, IndexTTS and the remaining adapters.
extension _OtherEngineFields on _CreateCharacterDialogState {
  List<Widget> _gptSovitsFields() => [
    VoiceCharacterSectionLabel(
      AppLocalizations.of(context).sectionGptSovitsMode,
    ),
    SizedBox(height: 8),
    VoiceCharacterGptSovitsModeSelector(
      selected: _gptSovitsMode,
      onChanged: (mode) {
        _update(() {
          _gptSovitsMode = mode;
          _taskMode = mode == 'clone'
              ? TaskMode.cloneWithPrompt
              : TaskMode.presetVoice;
          _selectedAudioTrackId = null;
          _uploadedRefAudioPath = null;
          if (mode == 'trained') {
            _promptTextCtrl.clear();
          }
        });
      },
    ),
    SizedBox(height: 20),
    if (_gptSovitsMode == 'trained') ...[
      VoiceCharacterSectionLabel(
        AppLocalizations.of(context).sectionTrainedSpeaker,
      ),
      SizedBox(height: 8),
      ..._buildSpeakerPicker(
        label: AppLocalizations.of(context).uiSelectSpeaker,
      ),
      TextField(
        controller: _voiceNameCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiSpeakerVoiceID,
          hintText: AppLocalizations.of(context).uiEGGenshinPaimon,
        ),
      ),
      SizedBox(height: 10),
      TextField(
        controller: _textLangCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiTextLanguageOptional,
          hintText: AppLocalizations.of(context).uiZhEnJaKo,
        ),
      ),
    ] else ...[
      ..._buildRefAudioPicker(),
      TextField(
        controller: _promptTextCtrl,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiPromptTextSpokenInRefAudio2,
          hintText: AppLocalizations.of(
            context,
          ).uiTranscriptOfTheReferenceAudio,
        ),
      ),
      SizedBox(height: 10),
      TextField(
        controller: _promptLangCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiPromptLanguage,
          hintText: AppLocalizations.of(context).uiZhEnJaKo,
        ),
      ),
      SizedBox(height: 10),
      TextField(
        controller: _textLangCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiTextLanguageSynthesisOutput,
          hintText: AppLocalizations.of(context).uiZhEnJaKo,
        ),
      ),
      SizedBox(height: 10),
      TextField(
        controller: _voiceNameCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiOutputSpeakerNameOptional,
          hintText: AppLocalizations.of(context).uiEGClone,
        ),
      ),
    ],
  ];

  List<Widget> _indexTtsFields() => [
    // ── IndexTTS: zero-shot clone from reference audio ──
    ..._buildRefAudioPicker(),
    TextField(
      controller: _textLangCtrl,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).uiTextLanguageSynthesisOutput,
        hintText: 'auto / ZH / EN / JA / AR / ES',
      ),
    ),
    SizedBox(height: 10),
    TextField(
      controller: _instructionCtrl,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).uiStyleInstruction,
        hintText: AppLocalizations.of(context).uiIndexTtsEmotionHint,
      ),
    ),
  ];

  List<Widget> _genericFields() => [
    // ── Fallback for other adapters (qwen3, etc.) ──
    VoiceCharacterSectionLabel(AppLocalizations.of(context).sectionVoice),
    SizedBox(height: 8),
    ..._buildSpeakerPicker(),
    TextField(
      controller: _voiceNameCtrl,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).uiVoiceSpeakerName,
      ),
    ),
  ];
}
