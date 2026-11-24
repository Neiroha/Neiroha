part of 'create_character_dialog.dart';

/// Builds the character row from the form and saves it.
extension _CreateCharacterSave on _CreateCharacterDialogState {
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).uiNameIsRequired)),
      );
      return;
    }

    final refAudio = _effectiveRefAudioPath;
    final block = kIsWeb
        ? browserSpeechBlock(
            provider: _selectedProvider,
            modelName: _modelNameCtrl.text,
            refAudioPath: refAudio,
            presetVoice: _voiceNameCtrl.text,
          )
        : null;
    if (block != null) {
      final message = browserSpeechMessage(AppLocalizations.of(context), block);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    // GPT-SoVITS and CosyVoice zero_shot / cross_lingual require ref audio.
    // cross_lingual can skip it only if a profile name is given instead.
    // VoxCPM2 clone / ultimate_clone need ref audio unless a registered
    // voice_id is chosen.
    // ChatCompletionsTts clone models need ref audio.
    final voxcpmNeedsAudio =
        _isVoxCpm2 &&
        (_voxcpmMode == 'clone' || _voxcpmMode == 'ultimate_clone') &&
        _voiceNameCtrl.text.trim().isEmpty;
    final chatCloneNeedsAudio =
        _isPresetVoiceProvider && _ttsModelType == 'clone';
    final needsRefAudio =
        _isIndexTts ||
        (_isGptSovits && _gptSovitsMode == 'clone') ||
        (_isCosyVoice && _cosyVoiceMode == 'zero_shot') ||
        (_isCosyVoice &&
            _cosyVoiceMode == 'cross_lingual' &&
            _voiceNameCtrl.text.trim().isEmpty) ||
        voxcpmNeedsAudio ||
        chatCloneNeedsAudio;
    final l10n = AppLocalizations.of(context);
    bool blank(TextEditingController c) => c.text.trim().isEmpty;
    final cloudClone = _isCloudCloneProvider && refAudio != null;
    // The first unmet requirement of the chosen engine and mode.
    final problem = [
      if (needsRefAudio && refAudio == null)
        kIsWeb
            ? l10n.webLocalAudioUnavailable
            : _isCosyVoice && _cosyVoiceMode == 'cross_lingual'
            ? 'Cross Lingual mode requires a Reference Audio or a Profile Name'
            : _isVoxCpm2
            ? 'VoxCPM2 ${_voxcpmMode == 'ultimate_clone' ? 'Ultra Clone' : 'Clone'} needs a Reference Audio or a Registered Voice'
            : 'Reference audio is required',
      if (_isGptSovits && _gptSovitsMode == 'trained' && blank(_voiceNameCtrl))
        l10n.uiSelectOrEnterAGPTSoVITSSpeaker,
      if (_isGptSovits && _gptSovitsMode == 'clone' && blank(_promptTextCtrl))
        l10n.uiGPTSoVITSCloneModeNeedsPromptText,
      if (_isVoxCpm2 && _voxcpmMode == null) l10n.uiSelectAVoxCPM2Mode,
      if (_isVoxCpm2 && _voxcpmMode == 'design' && blank(_instructionCtrl))
        l10n.uiDesignModeRequiresAVoiceDescription,
      if (_isPresetVoiceProvider &&
          _ttsModelType == 'design' &&
          blank(_instructionCtrl))
        l10n.uiVoiceDesignRequiresAVoiceDescription,
      if (_isVoxCpm2 &&
          _voxcpmMode == 'ultimate_clone' &&
          blank(_promptTextCtrl))
        l10n.uiUltraCloneModeRequiresAPromptText,
      if (_isCloudCloneProvider && !cloudClone && blank(_voiceNameCtrl))
        l10n.uiCloudVoiceCloneHint,
    ].firstOrNull;
    if (problem != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    _update(() => _saving = true);

    // ElevenLabs / MiniMax: register the reference audio as a reusable
    // voice upstream, then store the returned id as the preset voice.
    if (cloudClone) {
      try {
        final adapter = createAdapter(_selectedProvider);
        if (adapter is! VoiceCloneCapable) {
          throw Exception('Provider does not support voice cloning');
        }
        final cloned = await (adapter as VoiceCloneCapable).cloneVoice(
          name: name,
          audioPath: refAudio,
          promptText: _promptTextCtrl.text.trim(),
          description: _descCtrl.text.trim(),
        );
        _voiceNameCtrl.text = cloned;
      } catch (e) {
        if (mounted) {
          _update(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).uiCloudVoiceCloneFailed('$e'),
              ),
            ),
          );
        }
        return;
      }
    }

    // Determine task mode
    TaskMode effectiveMode;
    if (_isIndexTts) {
      effectiveMode = TaskMode.cloneWithPrompt;
    } else if (_isIrodori) {
      effectiveMode = refAudio == null
          ? TaskMode.presetVoice
          : TaskMode.cloneWithPrompt;
    } else if (_isPresetVoiceProvider) {
      if (_ttsModelType == 'clone') {
        effectiveMode = TaskMode.cloneWithPrompt;
      } else if (_ttsModelType == 'design') {
        effectiveMode = TaskMode.voiceDesign;
      } else {
        effectiveMode = TaskMode.presetVoice;
      }
    } else if (_isGptSovits) {
      effectiveMode = _gptSovitsMode == 'clone'
          ? TaskMode.cloneWithPrompt
          : TaskMode.presetVoice;
    } else {
      effectiveMode = _taskMode;
    }

    final assetId = const Uuid().v4();

    // Copy avatar to persistent location if picked
    String? persistedAvatarPath;
    if (_avatarPath != null) {
      try {
        final avatarDir = await PathService.instance.avatarsDir();
        final ext = p.extension(_avatarPath!);
        final dest = p.join(avatarDir.path, '$assetId$ext');
        await File(_avatarPath!).copy(dest);
        persistedAvatarPath = dest;
      } catch (_) {}
    }

    // Auto-save manually uploaded ref audio to voice assets library
    if (_uploadedRefAudioPath != null && _selectedAudioTrackId == null) {
      try {
        final vaDir = await PathService.instance.voiceCharacterRefDir();
        final trackId = const Uuid().v4();
        final ext = p.extension(_uploadedRefAudioPath!);
        final base = p.basenameWithoutExtension(_uploadedRefAudioPath!);
        final dest = PathService.dedupeFilename(
          vaDir,
          '${PathService.sanitizeSegment(base, fallback: 'ref')}_${PathService.formatTimestamp()}',
          ext,
        );
        await File(_uploadedRefAudioPath!).copy(dest);
        await widget.onSaveAudioTrack(
          db.AudioTracksCompanion(
            id: Value(trackId),
            name: Value(base),
            audioPath: Value(dest),
            refText: Value(
              _promptTextCtrl.text.trim().isEmpty
                  ? null
                  : _promptTextCtrl.text.trim(),
            ),
            refLang: Value(
              _promptLangCtrl.text.trim().isEmpty
                  ? null
                  : _promptLangCtrl.text.trim(),
            ),
            sourceType: const Value('upload'),
            createdAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {}
    }

    await widget.onSave(
      db.VoiceAssetsCompanion(
        id: Value(assetId),
        name: Value(name),
        description: Value(
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        ),
        providerId: Value(_selectedProviderId),
        modelBindingId: const Value(null),
        modelName: Value(
          (_isGptSovits || _isIndexTts)
              ? (_textLangCtrl.text.trim().isEmpty
                    ? null
                    : _textLangCtrl.text.trim())
              : _usesModelThenVoice
              ? (_modelNameCtrl.text.trim().isEmpty
                    ? null
                    : _modelNameCtrl.text.trim())
              // CosyVoice native: store the synthesis mode so the adapter
              // can route zero_shot / cross_lingual / instruct correctly.
              : _isCosyVoice
              ? _cosyVoiceMode
              // VoxCPM2 native: same pattern — store design / clone /
              // ultimate_clone so the adapter routes requests correctly.
              : _isVoxCpm2
              ? _voxcpmMode
              : null,
        ),
        taskMode: Value(effectiveMode.name),
        // Cloud clones live upstream; the sample stays in the audio library.
        refAudioPath: Value(cloudClone ? null : refAudio),
        refAudioTrimStart: const Value(null),
        refAudioTrimEnd: const Value(null),
        promptText: Value(
          _promptTextCtrl.text.trim().isEmpty
              ? null
              : _promptTextCtrl.text.trim(),
        ),
        promptLang: Value(
          _promptLangCtrl.text.trim().isEmpty
              ? null
              : _promptLangCtrl.text.trim(),
        ),
        voiceInstruction: Value(
          _instructionCtrl.text.trim().isEmpty
              ? null
              : _instructionCtrl.text.trim(),
        ),
        presetVoiceName: Value(
          _voiceNameCtrl.text.trim().isEmpty
              ? null
              : _voiceNameCtrl.text.trim(),
        ),
        avatarPath: Value(persistedAvatarPath),
      ),
    );

    if (mounted) Navigator.pop(context);
  }
}
