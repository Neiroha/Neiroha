part of 'editor.dart';

extension _VideoDubEditorGenerationActions on _VideoDubEditorState {
  /// Generate TTS for every cue. By default skips cues that already
  /// have audio; if any do, prompts the user with a Skip / Regenerate
  /// All / Cancel choice so the same button works for both first-pass
  /// generation and after-edit refresh.
  Future<void> _generateAll(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final pending = cues
        .where((c) => c.voiceAssetId != null && c.audioPath == null)
        .length;
    final alreadyDone = cues
        .where((c) => c.voiceAssetId != null && c.audioPath != null)
        .length;
    final missingVoice = cues.where((c) => c.voiceAssetId == null).length;

    bool forceRegen = false;
    if (alreadyDone > 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).uiGenerateAllCues),
          content: Text(
            '$alreadyDone cue(s) already have audio. '
            '$pending pending. '
            '${missingVoice > 0 ? '$missingVoice without a voice will be skipped. ' : ''}'
            'Regenerate the existing ones too, or only fill in the gaps?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'skip'),
              child: Text(AppLocalizations.of(context).uiOnlyPending),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'regen'),
              child: Text(AppLocalizations.of(context).uiRegenerateAll),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      forceRegen = choice == 'regen';
    } else if (pending == 0) {
      _snack('No cues to generate — assign a voice first');
      return;
    }

    await _runGenerateAll(project, cues, bankAssets, forceRegen: forceRegen);
  }

  /// Generation loop without the confirm dialog. Used by both the
  /// "Generate All" button (after its confirm) and the auto-TTS path
  /// after import. Reports a snackbar with done/failed counts.
  Future<void> _runGenerateAll(
    db.VideoDubProject project,
    List<db.SubtitleCue> cues,
    List<db.VoiceAsset> bankAssets, {
    required bool forceRegen,
  }) async {
    _updateState(() => _generatingAll = true);
    var done = 0;
    var failed = 0;
    try {
      final results = await Future.wait([
        for (final cue in cues)
          if (cue.voiceAssetId != null && (forceRegen || cue.audioPath == null))
            _generateOne(
              project,
              cue,
              bankAssets,
            ).then((_) => true).catchError((_) => false),
      ]);
      done = results.where((ok) => ok).length;
      failed = results.length - done;
    } finally {
      if (mounted) _updateState(() => _generatingAll = false);
    }
    if (done > 0) _markDirty();
    if (mounted) {
      _snack(
        'Generated $done cue(s)'
        '${failed > 0 ? ', $failed failed' : ''}',
      );
    }
  }

  Future<void> _generateOne(
    db.VideoDubProject project,
    db.SubtitleCue cue,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (cue.voiceAssetId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiAssignAVoiceToThisCueFirst,
            ),
          ),
        );
      }
      return;
    }
    // ttsProvidersStreamProvider isn't watched in this screen, so the
    // first read from valueOrNull is `null` until the stream warms up
    // — which is what made the auto-TTS path appear to "only work after
    // a manual generate". Read straight from the DB instead.
    final database = ref.read(databaseProvider);
    final providers = await database.getAllProviders();
    final assetMap = {for (final a in bankAssets) a.id: a};
    final providerMap = {for (final p in providers) p.id: p};
    final asset = assetMap[cue.voiceAssetId];
    if (asset == null) return;
    final provider = providerMap[asset.providerId];
    if (provider == null) return;

    final slug = await ref
        .read(storageServiceProvider)
        .ensureVideoDubProjectSlug(project.id);
    final outDir = await PathService.instance.videoDubDir(slug);

    _updateState(() => _generatingCueIds.add(cue.id));
    try {
      final result = await ref
          .read(ttsQueueServiceProvider)
          .synthesize(
            provider: provider,
            modelName: asset.modelName,
            source: 'Video Dub',
            label: 'Cue ${cue.orderIndex + 1}: ${cue.cueText}',
            request: TtsRequest(
              text: cue.cueText,
              voice: asset.presetVoiceName ?? asset.name,
              speed: asset.speed,
              textLang: provider.adapterType == 'gptSovits'
                  ? asset.modelName
                  : null,
              presetVoiceName: asset.presetVoiceName,
              voiceInstruction: asset.voiceInstruction,
              refAudioPath: asset.refAudioPath,
              promptText: asset.promptText,
              promptLang: asset.promptLang,
            ),
          );
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'cue_${cue.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      final durationSec = await _probeMediaDuration(filePath);
      await database.updateSubtitleCue(
        cue.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
      _markDirty();
    } catch (e) {
      await database.updateSubtitleCue(
        cue.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) _updateState(() => _generatingCueIds.remove(cue.id));
    }
  }

  /// Save bumps `updatedAt` so the project sorts to the top of the
  /// list, clears the dirty flag, and shows a confirmation snackbar.
  /// Stays in the editor — leaving is a separate action via the back
  /// arrow.
  Future<void> _save(db.VideoDubProject project) async {
    await ref
        .read(databaseProvider)
        .updateVideoDubProject(project.copyWith(updatedAt: DateTime.now()));
    if (!mounted) return;
    _updateState(() => _dirty = false);
    _snack('Saved');
  }

  /// Handle the back arrow. If there's unsaved work, prompt with
  /// Save & Exit / Discard / Cancel before leaving — otherwise just
  /// close. ("Discard" is a slight misnomer since edits are written to
  /// the DB immediately; it really just means "don't bump updatedAt".)
  Future<void> _back(db.VideoDubProject project) async {
    if (!_dirty) {
      widget.onClose();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiUnsavedChanges),
        content: Text(
          AppLocalizations.of(
            context,
          ).uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text("Don't save"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(AppLocalizations.of(context).uiSaveExit),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _save(project);
      if (mounted) widget.onClose();
    } else if (choice == 'discard') {
      if (mounted) widget.onClose();
    }
    // 'cancel' / null: stay in the editor.
  }
}
