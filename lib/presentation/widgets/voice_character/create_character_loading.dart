part of 'create_character_dialog.dart';

/// Voice, model and profile lookups, plus the shared pickers.
extension _CreateCharacterLoading on _CreateCharacterDialogState {
  /// Detect TTS model type from model name.
  /// Returns 'clone', 'design', or 'preset'.
  String _detectTtsModelType(String modelKey) {
    if (_isIrodori) return 'preset';
    final k = modelKey.toLowerCase();
    if (k.contains('voiceclone') || k.contains('clone')) return 'clone';
    if (k.contains('voicedesign') || k.contains('design')) return 'design';
    return 'preset';
  }

  /// Load available voices for the selected model.
  /// For MiMo preset models: returns built-in voice list.
  /// For other providers: loads from cached voice entries.
  Future<void> _loadVoicesForModel(String modelKey) async {
    final provider = _selectedProvider;
    _update(() {
      _loadingSpeakers = true;
      _speakers = [];
      _selectedSpeaker = null;
      _voiceNameCtrl.clear();
    });

    // Voices the chosen model ships with, then account / custom voices
    // (minus voices built into the provider's other models).
    final type = AdapterType.values.asNameMap()[provider.adapterType];
    List<String>? voiceSet;
    if (type == AdapterType.irodori) {
      try {
        final adapter = createAdapter(provider) as IrodoriAdapter;
        voiceSet = await adapter.getSpeakersForVoiceSet(modelKey);
      } catch (_) {
        // Keep cached voices available when the local backend is offline.
      }
    }
    final builtIn = type == null
        ? const <String>[]
        : builtInVoicesFor(type, modelKey);
    List<String> voiceList;
    if (voiceSet != null) {
      voiceList = voiceSet;
    } else if (builtIn.isNotEmpty &&
        type == AdapterType.chatCompletionsTts &&
        _ttsModelType == 'preset') {
      voiceList = builtIn;
    } else {
      final cachedVoices = await widget.database.getVoiceEntriesForProvider(
        provider.id,
      );
      final stored = cachedVoices.map((b) => b.modelKey);
      // Voices only other models offer would be rejected by this one.
      voiceList = type == null
          ? mergeVoices(builtIn, stored)
          : voiceChoices(type, modelKey, stored);
    }
    if (kIsWeb && provider.adapterType == 'openaiTts') {
      voiceList = browserOpenAiVoiceOptions(modelKey, voiceList);
    }
    if (mounted &&
        _selectedProviderId == provider.id &&
        _selectedModel == modelKey) {
      // A character always has a voice: start on the model's first one.
      final pickFirst =
          voiceList.isNotEmpty &&
          _voiceNameCtrl.text.trim().isEmpty &&
          (_ttsModelType == null || _ttsModelType == 'preset');
      _update(() {
        _speakers = voiceList;
        _loadingSpeakers = false;
        if (pickFirst) {
          _selectedSpeaker = voiceList.first;
          _voiceNameCtrl.text = voiceList.first;
        }
      });
      if (pickFirst) _autoFillName();
    }
  }

  Future<void> _fetchModelsAndSpeakers() async {
    _update(() {
      _loadingSpeakers = true;
      _loadingModels = true;
      _speakers = [];
      _models = [];
      _selectedSpeaker = null;
      _selectedModel = null;
      _modelNameCtrl.clear();
      _voiceNameCtrl.clear();
    });

    final provider = _selectedProvider;
    final adapterType = provider.adapterType;
    final hasSeparate = AdapterType.values
        .firstWhere(
          (t) => t.name == adapterType,
          orElse: () => AdapterType.openaiCompatible,
        )
        .hasSeparateModelAndVoice;

    if (_isGptSovits) {
      final cachedVoices = await widget.database.getVoiceEntriesForProvider(
        _selectedProviderId,
      );
      if (cachedVoices.isNotEmpty) {
        final voices = cachedVoices.map((b) => b.modelKey).toList()..sort();
        if (mounted) {
          _update(() {
            _speakers = voices;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        return;
      }

      try {
        final adapter = createAdapter(_selectedProvider);
        final speakers = await adapter.getSpeakers();
        if (mounted) {
          _update(() {
            _speakers = speakers;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      } catch (_) {
        if (mounted) {
          _update(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      }
      return;
    }

    if (hasSeparate) {
      final cachedModels = await widget.database.getModelEntriesForProvider(
        provider.id,
      );
      if (!mounted || _selectedProviderId != provider.id) return;
      final ids = cachedModels.map((b) => b.modelKey);
      final modelList = kIsWeb
          ? browserSpeechModels(provider, ids)
          : (ids.toList()..sort());
      final initial = kIsWeb && adapterType == 'openaiTts'
          ? browserSpeechModel(provider, null)
          : modelList.length == 1
          ? modelList.single
          : null;
      _update(() {
        _models = modelList;
        _loadingModels = false;
        _loadingSpeakers = initial != null;
        _selectedModel = initial;
        _modelNameCtrl.text = initial ?? '';
        _ttsModelType = initial == null ? null : _detectTtsModelType(initial);
      });
      if (initial != null) await _loadVoicesForModel(initial);
    } else {
      // CosyVoice native exposes profiles via /cosyvoice/profiles — fetch them
      // so the user can pick a registered one instead of typing a name that
      // the server will reject.
      if (_isCosyVoice) {
        if (mounted) {
          _update(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        _fetchCosyVoiceProfiles();
        return;
      }
      // VoxCPM2 native exposes registered voices via /api/voxcpm/voices — same
      // rationale: clone mode's `voice_id` must match a registered id.
      if (_isVoxCpm2) {
        if (mounted) {
          _update(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        _fetchVoxCpm2Voices();
        return;
      }
      // Voice-only providers (Azure, System TTS, GPT-SoVITS)
      final cached = await widget.database.getBindingsForProvider(
        _selectedProviderId,
      );
      if (cached.isNotEmpty) {
        final voices = cached.map((b) => b.modelKey).toList()..sort();
        if (mounted) {
          _update(() {
            _speakers = voices;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        return;
      }
      // No cache — live API fetch fallback
      try {
        final adapter = createAdapter(_selectedProvider);
        final speakers = await adapter.getSpeakers();
        if (mounted) {
          _update(() {
            _speakers = speakers;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      } catch (_) {
        if (mounted) {
          _update(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      }
    }
  }

  /// Live-fetch CosyVoice native profiles from `/cosyvoice/profiles`.
  Future<void> _fetchCosyVoiceProfiles() async {
    if (!_isCosyVoice) return;
    _update(() {
      _loadingCosyProfiles = true;
      _cosyProfiles = [];
      _selectedCosyProfileId = null;
    });
    try {
      final adapter = createAdapter(_selectedProvider);
      if (adapter is CosyVoiceAdapter) {
        final profiles = await adapter.getProfiles();
        if (mounted) {
          _update(() {
            _cosyProfiles = profiles;
            _loadingCosyProfiles = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) _update(() => _loadingCosyProfiles = false);
  }

  /// Live-fetch VoxCPM2 registered voices from `/api/voxcpm/voices`.
  Future<void> _fetchVoxCpm2Voices() async {
    if (!_isVoxCpm2) return;
    _update(() {
      _loadingVoxcpmVoices = true;
      _voxcpmVoices = [];
      _selectedVoxcpmVoiceId = null;
    });
    try {
      final adapter = createAdapter(_selectedProvider);
      if (adapter is VoxCpm2NativeAdapter) {
        final voices = await adapter.getVoices();
        if (mounted) {
          _update(() {
            _voxcpmVoices = voices;
            _loadingVoxcpmVoices = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) _update(() => _loadingVoxcpmVoices = false);
  }

  /// Reusable searchable speaker picker + loading indicator.
  List<Widget> _buildSpeakerPicker({String label = 'Select Voice'}) {
    if (_loadingSpeakers) {
      return [
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
        ),
      ];
    }
    if (_speakers.isNotEmpty) {
      return [
        VoiceCharacterVoiceSearchPicker(
          label: label,
          voices: _speakers,
          selected: _selectedSpeaker,
          onSelected: (v) => _update(() {
            _selectedSpeaker = v;
            _voiceNameCtrl.text = v;
            _autoFillName();
          }),
        ),
        SizedBox(height: 8),
      ];
    }
    return [];
  }

  /// Build the reference audio picker with voice asset library support.
  List<Widget> _buildRefAudioPicker() {
    if (kIsWeb) {
      return [Text(AppLocalizations.of(context).webLocalAudioUnavailable)];
    }
    return [
      VoiceCharacterSectionLabel(
        AppLocalizations.of(context).sectionReferenceAudio,
      ),
      SizedBox(height: 8),
      // Pick from voice assets library
      if (widget.audioTracks.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiSelectFromVoiceAssets,
            prefixIcon: Icon(Icons.library_music_rounded, size: 18),
          ),
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                AppLocalizations.of(context).uiNoneUploadManually,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            ...widget.audioTracks.map(
              (t) => DropdownMenuItem(
                value: t.id,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          initialValue: _selectedAudioTrackId,
          onChanged: (v) {
            _update(() {
              _selectedAudioTrackId = v;
              if (v != null) {
                _uploadedRefAudioPath = null;
                // Auto-fill prompt text/lang from track metadata
                final track = widget.audioTracks
                    .where((t) => t.id == v)
                    .firstOrNull;
                if (track != null) {
                  if (track.refText != null &&
                      track.refText!.isNotEmpty &&
                      _promptTextCtrl.text.isEmpty) {
                    _promptTextCtrl.text = track.refText!;
                  }
                  if (track.refLang != null &&
                      track.refLang!.isNotEmpty &&
                      _promptLangCtrl.text == 'zh') {
                    _promptLangCtrl.text = track.refLang!;
                  }
                }
              }
            });
          },
        ),
        SizedBox(height: 10),
        if (_selectedAudioTrackId == null) ...[
          Text(
            AppLocalizations.of(context).uiOrUploadANewFile,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.fg.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(height: 8),
        ],
      ],
      // Manual upload (shown when no track selected or no tracks exist)
      if (_selectedAudioTrackId == null)
        VoiceCharacterRefAudioPicker(
          path: _uploadedRefAudioPath,
          onPick: (path) => _update(() => _uploadedRefAudioPath = path),
        ),
      SizedBox(height: 12),
    ];
  }

  Future<void> _pickAvatarForCreate() async {
    final result = await pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    _update(() => _avatarPath = result.files.single.path!);
  }

  void _autoFillName() {
    final providerName = _selectedProvider.name;
    final model = _modelNameCtrl.text.trim().isNotEmpty
        ? _modelNameCtrl.text.trim()
        : (_selectedModel ?? '');
    final speaker = _voiceNameCtrl.text.trim().isNotEmpty
        ? _voiceNameCtrl.text.trim()
        : (_selectedSpeaker ?? '');
    // Build: provider_model_voice (skip empty parts)
    final parts = <String>[providerName];
    if (model.isNotEmpty) parts.add(model);
    if (speaker.isNotEmpty) parts.add(speaker);
    _nameCtrl.text = parts.join('_');
  }
}
