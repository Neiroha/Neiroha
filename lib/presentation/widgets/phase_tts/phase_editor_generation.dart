part of '../../screens/phase_tts_screen.dart';

/// Projects, script splitting, voices, generation and merged export.
extension _PhaseEditorGeneration on _PhaseTtsScreenState {
  void _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).value ?? const [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiCreateAVoiceBankFirst),
          ),
        );
      }
      return;
    }

    final result = await showCreatePhaseTtsProjectDialog(
      context: context,
      banks: banks,
    );
    if (result == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    await ref
        .read(databaseProvider)
        .insertPhaseTtsProject(
          db.PhaseTtsProjectsCompanion(
            id: Value(id),
            name: Value(result.name),
            bankId: Value(result.bankId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (mounted) {
      _update(() {
        _selectedProjectId = id;
        _dirty = false;
        _scriptController.clear();
      });
    }
  }

  void _saveScript(db.PhaseTtsProject project) {
    _markDirty();
    final database = ref.read(databaseProvider);
    final nextProject = project.copyWith(scriptText: _scriptController.text);
    _pendingScriptWrite = _pendingScriptWrite.catchError((_) {}).then((_) {
      return database.updatePhaseTtsProject(nextProject);
    });
  }

  Future<void> _autoSplit(
    db.PhaseTtsProject project,
    SplitRule rule,
    List<db.PhaseTtsSegment> existing,
  ) async {
    final text = _scriptController.text;
    if (text.trim().isEmpty) return;
    if (existing.isNotEmpty && !await _confirmResplit(existing.length)) return;
    _markDirty();

    final database = ref.read(databaseProvider);
    await database.clearPhaseTtsSegments(project.id);
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(project.id);
    await ref.read(phaseSegmentSettingsFileServiceProvider).delete(slug);
    final segments = applySplitRule(rule, text);

    for (var i = 0; i < segments.length; i++) {
      await database.insertPhaseTtsSegment(
        db.PhaseTtsSegmentsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(project.id),
          orderIndex: Value(i),
          segmentText: Value(segments[i]),
        ),
      );
    }
  }

  Future<bool> _confirmResplit(int count) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.phaseResplitTitle),
        content: Text(l10n.phaseResplitBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.phaseResplitConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _applyVoiceToAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> currentSegments,
    String? voiceId,
  ) async {
    final database = ref.read(databaseProvider);
    final segments = currentSegments.isEmpty
        ? await database.getPhaseTtsSegments(project.id)
        : currentSegments;
    for (final segment in segments) {
      await database.updatePhaseTtsSegment(
        segment.copyWith(voiceAssetId: Value(voiceId)),
      );
    }
    _markDirty();
  }

  Future<void> _updateSegmentVoice(
    db.PhaseTtsSegment segment,
    String? voiceId,
  ) async {
    await ref
        .read(databaseProvider)
        .updatePhaseTtsSegment(segment.copyWith(voiceAssetId: Value(voiceId)));
    _markDirty();
  }

  Future<PhaseSegmentSettings> _loadSegmentSettings(
    db.PhaseTtsProject project,
  ) async {
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(project.id);
    return ref.read(phaseSegmentSettingsFileServiceProvider).load(slug);
  }

  /// Generate every pending segment that has a voice.
  Future<void> _generateAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) => _generateBatch(project, [
    for (final seg in segments)
      if (seg.audioPath == null && seg.voiceAssetId != null) seg,
  ], bankAssets);

  /// Generate [targets] (regenerating ones that already have audio) under a
  /// shared cancel token so "Stop" drops whatever has not started yet.
  Future<void> _generateBatch(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> targets,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (targets.isEmpty || bankAssets.isEmpty || _generatingAll) return;
    final token = TtsCancelToken();
    _update(() {
      _generatingAll = true;
      _cancelToken = token;
    });
    try {
      final segmentSettings = await _loadSegmentSettings(project);
      await Future.wait([
        for (final seg in targets)
          _generateOne(
            project,
            seg,
            bankAssets,
            segmentSettings: segmentSettings,
            cancelToken: token,
          ),
      ]);
    } finally {
      if (mounted) {
        _update(() {
          _generatingAll = false;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _generateOne(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets, {
    PhaseSegmentSettings? segmentSettings,
    TtsCancelToken? cancelToken,
  }) async {
    if (seg.voiceAssetId == null) return;
    if (cancelToken?.isCancelled ?? false) return;
    final database = ref.read(databaseProvider);

    _update(() => _generatingSegmentIds.add(seg.id));
    try {
      final providers = await database.getAllProviders();
      final assetMap = {for (final a in bankAssets) a.id: a};
      final providerMap = {for (final p in providers) p.id: p};
      final asset = assetMap[seg.voiceAssetId];
      if (asset == null) return;
      final provider = providerMap[asset.providerId];
      if (provider == null) return;
      if (mounted) {
        warnIfVoiceHealthFailedOnce(context: context, ref: ref, asset: asset);
      }

      final settings = segmentSettings ?? await _loadSegmentSettings(project);
      final overrides = settings.bySegmentId[seg.id];
      final instructionOverride = overrides?.voiceInstruction?.trim();
      final audioTagPrefix = overrides?.audioTagPrefix?.trim();
      final slug = await ref
          .read(storageServiceProvider)
          .ensurePhaseProjectSlug(project.id);
      final outDir = await PathService.instance.phaseTtsDir(slug);

      final result = await ref
          .read(ttsQueueServiceProvider)
          .synthesize(
            provider: provider,
            modelName: asset.modelName,
            source: 'Phase TTS',
            label: 'Segment ${seg.orderIndex + 1}: ${seg.segmentText}',
            cancelToken: cancelToken,
            request: TtsRequest(
              text: seg.segmentText,
              voice: asset.presetVoiceName ?? asset.name,
              voiceAssetId: asset.id,
              speed: asset.speed,
              textLang: TtsRequest.legacyTextLanguage(
                provider.adapterType,
                asset.modelName,
              ),
              presetVoiceName: asset.presetVoiceName,
              voiceInstruction:
                  VoiceCapabilities.supportsVoiceInstruction(asset, provider)
                  ? (instructionOverride == null || instructionOverride.isEmpty
                        ? asset.voiceInstruction
                        : instructionOverride)
                  : null,
              audioTagPrefix:
                  VoiceCapabilities.supportsAudioTags(asset, provider)
                  ? (audioTagPrefix == null || audioTagPrefix.isEmpty
                        ? null
                        : audioTagPrefix)
                  : null,
              refAudioPath: asset.refAudioPath,
              promptText: asset.promptText,
              promptLang: asset.promptLang,
            ),
          );
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'seg_${seg.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      await ref
          .read(autoLoudnessServiceProvider)
          .normalizeGenerated(
            enabled: project.autoNormalizeLoudness,
            path: filePath,
            bankId: project.bankId,
            voiceAssetId: asset.id,
          );
      final durationSec = await measureAudioDuration(filePath);
      await database.updatePhaseTtsSegment(
        seg.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
      _markDirty();
    } on TtsCancelledException {
      // Stopped before it started: leave the segment pending.
    } catch (e) {
      await database.updatePhaseTtsSegment(
        seg.copyWith(error: Value(e.toString())),
      );
      _markDirty();
    } finally {
      if (mounted) _update(() => _generatingSegmentIds.remove(seg.id));
    }
  }

  Future<void> _exportMerged(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
  ) async {
    _update(() => _exportingMerged = true);
    try {
      await exportPhaseTtsMergedAudio(
        context: context,
        ref: ref,
        project: project,
        segments: segments,
      );
    } finally {
      if (mounted) _update(() => _exportingMerged = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
