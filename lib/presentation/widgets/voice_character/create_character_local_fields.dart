part of 'create_character_dialog.dart';

/// Fields for CosyVoice and VoxCPM2.
extension _LocalEngineFields on _CreateCharacterDialogState {
  List<Widget> _cosyVoiceFields() => [
    // ── CosyVoice: 3 modes ──
    VoiceCharacterSectionLabel(
      AppLocalizations.of(context).sectionCosyvoiceMode,
    ),
    SizedBox(height: 8),
    VoiceCharacterCosyVoiceModeSelector(
      selected: _cosyVoiceMode,
      onChanged: (mode) {
        _update(() {
          _cosyVoiceMode = mode;
          // cross_lingual also clones from reference audio
          if (mode == 'zero_shot' || mode == 'cross_lingual') {
            _taskMode = TaskMode.cloneWithPrompt;
          } else if (mode == 'instruct') {
            _taskMode = TaskMode.voiceDesign;
          } else {
            _taskMode = TaskMode.presetVoice;
          }
        });
      },
    ),
    SizedBox(height: 20),
    if (_cosyVoiceMode != null) ...[
      VoiceCharacterSectionLabel(
        AppLocalizations.of(context).sectionServerProfileOptional,
      ),
      SizedBox(height: 4),
      Text(
        AppLocalizations.of(
          context,
        ).uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise,
        style: TextStyle(
          fontSize: 12,
          color: context.fg.withValues(alpha: 0.4),
        ),
      ),
      SizedBox(height: 8),
      if (_loadingCosyProfiles)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(AppLocalizations.of(context).uiLoadingServerProfiles),
            ],
          ),
        )
      else
        DropdownButtonFormField<String?>(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiServerProfile,
            prefixIcon: Icon(Icons.folder_shared_rounded, size: 18),
          ),
          isExpanded: true,
          initialValue: _selectedCosyProfileId,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                AppLocalizations.of(context).uiNoneUseUploadedAudioOnly,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            ..._cosyProfiles.map(
              (p) => DropdownMenuItem<String?>(
                value: p.id,
                child: Text(
                  p.modeLabel.isNotEmpty
                      ? '${p.name}  ·  ${p.modeLabel}'
                      : p.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (v) => _update(() {
            _selectedCosyProfileId = v;
            _voiceNameCtrl.text = v ?? '';
          }),
        ),
      SizedBox(height: 12),

      // ── Zero Shot ──────────────────────────────────────────
      if (_cosyVoiceMode == 'zero_shot') ...[
        ..._buildRefAudioPicker(),
        TextField(
          controller: _promptTextCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(
              context,
            ).uiPromptTextSpokenInRefAudio,
            hintText: AppLocalizations.of(
              context,
            ).uiTranscriptOfTheReferenceAudio,
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _promptLangCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiLanguageCode,
            hintText: AppLocalizations.of(context).uiZhEnJaKo,
          ),
        ),
      ],

      // ── Cross Lingual ──────────────────────────────────────
      if (_cosyVoiceMode == 'cross_lingual') ...[
        VoiceCharacterSectionLabel(
          AppLocalizations.of(context).sectionReferenceAudio,
        ),
        SizedBox(height: 4),
        Text(
          AppLocalizations.of(
            context,
          ).uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak,
          style: TextStyle(
            fontSize: 12,
            color: context.fg.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 8),
        ..._buildRefAudioPicker(),
      ],

      // ── Instruct ───────────────────────────────────────────
      if (_cosyVoiceMode == 'instruct') ...[
        VoiceCharacterSectionLabel(
          AppLocalizations.of(context).sectionInstruct,
        ),
        SizedBox(height: 8),
        TextField(
          controller: _instructionCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiInstructText,
            hintText: AppLocalizations.of(context).uiEGOrSpeakWithExcitement,
          ),
        ),
        SizedBox(height: 16),
        VoiceCharacterSectionLabel('REFERENCE AUDIO (optional)'),
        SizedBox(height: 4),
        Text(
          AppLocalizations.of(
            context,
          ).uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf,
          style: TextStyle(
            fontSize: 12,
            color: context.fg.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 8),
        ..._buildRefAudioPicker(),
      ],
    ],
  ];

  List<Widget> _voxCpm2Fields() => [
    // ── VoxCPM2 Native: 3 modes ──
    VoiceCharacterSectionLabel(AppLocalizations.of(context).sectionVoxcpm2Mode),
    SizedBox(height: 8),
    VoiceCharacterVoxCpm2ModeSelector(
      selected: _voxcpmMode,
      onChanged: (mode) {
        _update(() {
          _voxcpmMode = mode;
          // design: text-only → voiceDesign task mode.
          // clone / ultimate_clone: require audio → cloneWithPrompt.
          if (mode == 'design') {
            _taskMode = TaskMode.voiceDesign;
          } else {
            _taskMode = TaskMode.cloneWithPrompt;
          }
        });
      },
    ),
    SizedBox(height: 20),
    if (_voxcpmMode != null) ...[
      // Registered voice picker (optional — only meaningful in
      // clone / ultimate_clone; for design we still show it
      // disabled-via-empty-list so the UI is consistent).
      if (_voxcpmMode != 'design') ...[
        VoiceCharacterSectionLabel('REGISTERED VOICE (optional)'),
        SizedBox(height: 4),
        Text(
          AppLocalizations.of(
            context,
          ).uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise,
          style: TextStyle(
            fontSize: 12,
            color: context.fg.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 8),
        if (_loadingVoxcpmVoices)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(AppLocalizations.of(context).uiLoadingRegisteredVoices),
              ],
            ),
          )
        else
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiRegisteredVoice,
              prefixIcon: Icon(Icons.folder_shared_rounded, size: 18),
            ),
            isExpanded: true,
            initialValue: _selectedVoxcpmVoiceId,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  AppLocalizations.of(context).uiNoneUseUploadedAudioOnly,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
              ..._voxcpmVoices.map(
                (v) => DropdownMenuItem<String?>(
                  value: v.id,
                  child: Text(
                    v.displayName.isNotEmpty
                        ? '${v.displayName}  ·  ${v.id}'
                        : v.id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => _update(() {
              _selectedVoxcpmVoiceId = v;
              _voiceNameCtrl.text = v ?? '';
            }),
          ),
        SizedBox(height: 12),
      ],

      // ── Design ─────────────────────────────────────────────
      if (_voxcpmMode == 'design') ...[
        VoiceCharacterSectionLabel(
          AppLocalizations.of(context).sectionVoiceDescription,
        ),
        SizedBox(height: 4),
        Text(
          AppLocalizations.of(
            context,
          ).uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText,
          style: TextStyle(
            fontSize: 12,
            color: context.fg.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _instructionCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiVoiceDescription,
            hintText: AppLocalizations.of(
              context,
            ).uiAYoungWomanGentleAndSweetVoice,
          ),
        ),
      ],

      // ── Clone ──────────────────────────────────────────────
      if (_voxcpmMode == 'clone') ...[..._buildRefAudioPicker()],

      // ── Ultimate Clone ─────────────────────────────────────
      if (_voxcpmMode == 'ultimate_clone') ...[
        ..._buildRefAudioPicker(),
        TextField(
          controller: _promptTextCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(
              context,
            ).uiPromptTextSpokenInRefAudio2,
            hintText: AppLocalizations.of(
              context,
            ).uiTranscriptOfTheReferenceAudio,
          ),
        ),
      ],
    ],
  ];
}
