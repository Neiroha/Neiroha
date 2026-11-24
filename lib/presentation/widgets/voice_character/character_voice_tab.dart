part of 'character_inspector.dart';

/// The Voice tab: provider, speed and the adapter's own fields.
extension _CharacterVoiceTab on _CharacterInspectorState {
  List<Widget> _voiceTab({
    required db.VoiceAsset a,
    required List<db.TtsProvider> allProviders,
    required List<db.TtsProvider> enabledProviders,
    required db.TtsProvider? selected,
    required List<String> voices,
    required PlatformCapabilities capabilities,
  }) => [
    VoiceCharacterSectionLabel(AppLocalizations.of(context).sectionProvider),
    SizedBox(height: 8),
    if (enabledProviders.isEmpty)
      Text(
        AppLocalizations.of(context).uiNoProvidersAvailable,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      )
    else
      DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiProvider,
        ),
        initialValue: enabledProviders.any((p) => p.id == _selectedProviderId)
            ? _selectedProviderId
            : null,
        items: enabledProviders
            .map(
              (p) => DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Text(p.name),
                    SizedBox(width: 8),
                    Text(
                      '(${AdapterType.values.where((t) => t.name == p.adapterType).firstOrNull?.displayName ?? p.adapterType})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            _update(() {
              _selectedProviderId = v;
              _speakers = [];
              _selectedSpeaker = null;
            });
            _fetchSpeakers();
          }
        },
      ),
    SizedBox(height: 16),

    // ── Speed ────────────────────────────────────────────────────────────
    TextField(
      controller: _speedCtrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).uiSpeed10Normal,
      ),
    ),
    SizedBox(height: 12),
    CharacterLoudnessOffsetField(
      value: _loudnessOffsetDb,
      onChanged: (v) => _update(() => _loudnessOffsetDb = v),
    ),
    SizedBox(height: 20),

    // ── Mode-specific fields ─────────────────────────────────────────────
    if (a.taskMode == 'presetVoice') ...[
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
      else if (voices.isNotEmpty) ...[
        VoiceCharacterVoiceSearchPicker(
          label: AppLocalizations.of(context).uiSelectVoice,
          voices: voices,
          selected: voices.contains(_selectedSpeaker) ? _selectedSpeaker : null,
          onSelected: (v) {
            _update(() {
              _selectedSpeaker = v;
              _voiceNameCtrl.text = v;
            });
            _persistVoice(v);
          },
        ),
        SizedBox(height: 8),
      ],
      TextField(
        controller: _voiceNameCtrl,
        onChanged: (_) => _update(() {}),
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiVoiceName,
          helperText: AppLocalizations.of(
            context,
          ).uiFilledAutomaticallyWhenYouPickAboveOrTypeManually,
          errorText: _voiceProblem(voices),
          errorMaxLines: 3,
        ),
      ),
      if (_hasModelField) ...[
        SizedBox(height: 12),
        CharacterModelField(
          controller: _modelNameCtrl,
          provider: selected,
          isWeb: capabilities.isWeb,
          onChanged: () {
            _update(() {});
            // Voices depend on the model.
            _fetchSpeakers();
          },
        ),
      ],
      if (_isGptSovits) ...[
        SizedBox(height: 12),
        TextField(
          controller: _textLangCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiTextLanguageOptional,
            hintText: AppLocalizations.of(context).uiZhEnJaKo,
          ),
        ),
      ],
      if (const {
        'openaiTts',
        'geminiTts',
        'elevenLabs',
        'minimaxTts',
      }.contains(_selectedProvider?.adapterType)) ...[
        SizedBox(height: 12),
        TextField(
          controller: _instructionCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiStyleInstructionOptional,
            hintText: AppLocalizations.of(
              context,
            ).uiEGSpeakSoftlyAndSlowlyPrependedToTheText,
          ),
        ),
      ],
    ],

    if (a.taskMode == 'cloneWithPrompt') ...[
      VoiceCharacterSectionLabel(
        AppLocalizations.of(context).sectionVoiceClone,
      ),
      SizedBox(height: 8),
      if (_isIrodori) ...[
        CharacterModelField(
          controller: _modelNameCtrl,
          provider: selected,
          isWeb: capabilities.isWeb,
          onChanged: () {
            _update(() {});
            // Voices depend on the model.
            _fetchSpeakers();
          },
        ),
        SizedBox(height: 12),
      ],
      if (!kIsWeb && a.refAudioPath != null) ...[
        Text(
          AppLocalizations.of(context).uiREFERENCEAUDIO,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDim,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final playback = ref.watch(
                    playbackNotifierProvider.select(
                      (state) => (
                        audioPath: state.audioPath,
                        isPlaying: state.isPlaying,
                      ),
                    ),
                  );
                  final isPlaying =
                      playback.audioPath == a.refAudioPath &&
                      playback.isPlaying;
                  return IconButton.filled(
                    onPressed: () async {
                      final n = ref.read(playbackNotifierProvider.notifier);
                      if (isPlaying) {
                        await n.stop();
                      } else {
                        await n.load(
                          a.refAudioPath!,
                          '${a.name} (ref)',
                          subtitle: a.name,
                        );
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      minimumSize: const Size(36, 36),
                    ),
                    icon: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                  );
                },
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.refAudioPath!.split(Platform.pathSeparator).last,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (a.refAudioTrimStart != null ||
                        a.refAudioTrimEnd != null)
                      Text(
                        '${a.refAudioTrimStart?.toStringAsFixed(1) ?? '0.0'}s'
                        ' → ${a.refAudioTrimEnd?.toStringAsFixed(1) ?? 'end'}s',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
      ],
      if (!_isIrodori) ...[
        TextField(
          controller: _promptTextCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiReferenceTranscript,
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _promptLangCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiLanguageCode,
          ),
        ),
      ],
      if (_usesTextLang) ...[
        SizedBox(height: 10),
        TextField(
          controller: _textLangCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(
              context,
            ).uiTextLanguageSynthesisOutput,
            hintText: AppLocalizations.of(context).uiZhEnJaKo,
          ),
        ),
      ],
      SizedBox(height: 10),
      TextField(
        controller: _instructionCtrl,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiStyleInstructionOptional,
        ),
      ),
    ],

    if (a.taskMode == 'voiceDesign') ...[
      VoiceCharacterSectionLabel(
        AppLocalizations.of(context).sectionVoiceDesign,
      ),
      SizedBox(height: 8),
      TextField(
        controller: _instructionCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).uiVoiceInstruction,
        ),
      ),
    ],

    if (supportsQuickTtsStreaming(
      allProviders.where((p) => p.id == a.providerId).firstOrNull,
      a,
      capabilities,
    )) ...[
      const SizedBox(height: 8),
      QuickTtsPlaybackSetting(voiceId: a.id),
    ],
  ];

  /// Why the voice cannot be used with the chosen model, if it cannot.
  String? _voiceProblem(List<String> voices) {
    final l10n = AppLocalizations.of(context);
    final voice = _voiceNameCtrl.text.trim();
    final model = _modelNameCtrl.text.trim();
    final type = AdapterType.values.asNameMap()[_selectedProvider?.adapterType];
    if (voice.isEmpty) {
      // Reference audio stands in for a voice on clone-capable engines.
      final cloned = widget.asset.refAudioPath?.isNotEmpty ?? false;
      return voices.isEmpty || cloned ? null : l10n.voiceRequired;
    }
    if (type != null && voiceUnsupported(type, model, voice)) {
      return l10n.voiceNotForModel(voice, model);
    }
    return null;
  }

  /// A picked voice takes effect at once, since the quick test reads the
  /// saved character; only while the provider and model are the saved ones.
  Future<void> _persistVoice(String voice) async {
    final a = widget.asset;
    final model = _modelNameCtrl.text.trim();
    if (_selectedProviderId != a.providerId ||
        model != (a.modelName ?? '').trim() ||
        voice == a.presetVoiceName) {
      return;
    }
    await ref
        .read(databaseProvider)
        .updateVoiceAsset(a.copyWith(presetVoiceName: Value(voice)));
  }
}
