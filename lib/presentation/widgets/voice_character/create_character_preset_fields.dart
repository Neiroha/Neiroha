part of 'create_character_dialog.dart';

/// Fields for preset-voice and cloud-clone providers.
extension _PresetVoiceFields on _CreateCharacterDialogState {
  List<Widget> _presetVoiceFields() => [
    if (_usesModelThenVoice) ...[
      // ── Step 1: Select Model ──
      VoiceCharacterSectionLabel(AppLocalizations.of(context).sectionModel),
      SizedBox(height: 8),
      if (_loadingModels)
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
              Text(AppLocalizations.of(context).uiLoadingModels),
            ],
          ),
        )
      else if (_models.isNotEmpty) ...[
        VoiceCharacterVoiceSearchPicker(
          label: AppLocalizations.of(context).uiSelectModel,
          voices: _models,
          selected: _selectedModel,
          onSelected: (v) {
            final modelType = _detectTtsModelType(v);
            _update(() {
              _selectedModel = v;
              _modelNameCtrl.text = v;
              _ttsModelType = modelType;
              // Reset voice state when model changes
              _selectedSpeaker = null;
              _voiceNameCtrl.clear();
              _uploadedRefAudioPath = null;
              _selectedAudioTrackId = null;
              _instructionCtrl.clear();
            });
            _loadVoicesForModel(v);
            _autoFillName();
          },
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            AppLocalizations.of(
              context,
            ).uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],

      // ── Step 2: Contextual UI based on selected model type ──
      if (_selectedModel != null && _ttsModelType != null) ...[
        SizedBox(height: 16),

        // ── Preset Voice: voice picker ──
        if (_ttsModelType == 'preset') ...[
          VoiceCharacterSectionLabel(AppLocalizations.of(context).sectionVoice),
          SizedBox(height: 8),
          if (_loadingSpeakers)
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
                  Text(AppLocalizations.of(context).uiLoadingVoices),
                ],
              ),
            )
          else if (_speakers.isNotEmpty)
            VoiceCharacterVoiceSearchPicker(
              label: AppLocalizations.of(context).uiSelectVoice,
              voices: _speakers,
              selected: _selectedSpeaker,
              onSelected: (v) => _update(() {
                _selectedSpeaker = v;
                _voiceNameCtrl.text = v;
                _autoFillName();
              }),
            ),
          SizedBox(height: 8),
          TextField(
            controller: _voiceNameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiVoiceSpeakerID,
              hintText: AppLocalizations.of(context).uiEGAlloyOrGenshinPaimon,
            ),
            onChanged: (_) => _autoFillName(),
          ),
          if (_isGeminiTts || _isOpenAiTts || _isCloudCloneProvider) ...[
            PresetVoiceStyleFields(
              controller: _instructionCtrl,
              adapterType: _adapterType,
            ),
          ],
          if (_isCloudCloneProvider) ...[
            SizedBox(height: 16),
            VoiceCharacterSectionLabel('CLONE A NEW VOICE (optional)'),
            SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).uiCloudVoiceCloneHint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: 8),
            ..._buildRefAudioPicker(),
          ],
          if (_isIrodori && !kIsWeb) ...[
            SizedBox(height: 16),
            ..._buildRefAudioPicker(),
            if (_effectiveRefAudioPath != null)
              TextField(
                controller: _instructionCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(
                    context,
                  ).uiStyleInstructionOptional,
                ),
              ),
          ],
        ],

        // ── Voice Clone: ref audio upload ──
        if (_ttsModelType == 'clone') ...[
          ..._buildRefAudioPicker(),
          VoiceCharacterSectionLabel(
            AppLocalizations.of(context).sectionVoiceNameOptional,
          ),
          SizedBox(height: 4),
          Text(
            AppLocalizations.of(
              context,
            ).uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _voiceNameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiVoiceName,
              hintText: AppLocalizations.of(context).uiEGMyClonedVoice,
            ),
          ),
        ],

        // ── Voice Design: text description ──
        if (_ttsModelType == 'design') ...[
          VoiceCharacterSectionLabel(
            AppLocalizations.of(context).sectionVoiceDescription,
          ),
          SizedBox(height: 4),
          Text(
            AppLocalizations.of(
              context,
            ).uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
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
              ).uiEGHeavyRussianAccentGruffMiddleAgedMale,
            ),
          ),
        ],
      ],
    ] else ...[
      // ── Azure / System TTS: voices only ──
      VoiceCharacterSectionLabel(
        _adapterType == 'azureTts' ? 'VOICE' : 'PRESET VOICE',
      ),
      SizedBox(height: 8),
      ..._buildSpeakerPicker(
        label: _adapterType == 'azureTts' ? 'Select Voice' : 'Select Speaker',
      ),
      TextField(
        controller: _voiceNameCtrl,
        decoration: InputDecoration(
          labelText: _adapterType == 'azureTts'
              ? 'Voice Name'
              : 'Voice / Speaker Name',
          hintText: _adapterType == 'azureTts'
              ? 'e.g. en-US-AriaNeural'
              : 'e.g. alloy, mimo_default',
        ),
      ),
    ],
  ];
}
