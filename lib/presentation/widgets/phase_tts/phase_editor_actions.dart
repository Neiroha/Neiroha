part of '../../screens/phase_tts_screen.dart';

/// Segment edits, saving, leaving and playback in the Phase TTS editor.
extension _PhaseEditorActions on _PhaseTtsScreenState {
  /// Delete with a snackbar undo that puts the rows back in place.
  Future<void> _deleteSegments(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> rows,
  ) async {
    if (rows.isEmpty) return;
    final database = ref.read(databaseProvider);
    await database.deletePhaseSegments(project.id, rows.map((s) => s.id));
    _markDirty();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.phaseDeletedCount(rows.length)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.phaseUndo,
          onPressed: () =>
              unawaited(database.restorePhaseSegments(project.id, rows)),
        ),
      ),
    );
  }

  /// Highlight [segment] inside the script. Segments are located in order,
  /// each search starting where the previous one ended, so repeated
  /// sentences resolve to the right occurrence.
  void _revealInScript(
    db.PhaseTtsSegment segment,
    List<db.PhaseTtsSegment> segments,
  ) {
    final script = _scriptController.text;
    final ordered = [...segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    var cursor = 0;
    for (final s in ordered) {
      final needle = s.segmentText.trim();
      if (needle.isEmpty) continue;
      final at = script.indexOf(needle, cursor);
      if (s.id == segment.id) {
        // Fall back to a global search when earlier segments were edited.
        final hit = at >= 0 ? at : script.indexOf(needle);
        if (hit < 0) {
          _scriptController.clearHighlight();
        } else {
          _scriptController.reveal(
            TextRange(start: hit, end: hit + needle.length),
          );
        }
        return;
      }
      if (at >= 0) cursor = at + needle.length;
    }
  }

  Future<void> _showMergeSettings(db.PhaseTtsProject project) async {
    final result = await showPhaseMergeSettingsDialog(
      context: context,
      project: project,
    );
    if (result == null) return;
    await ref.read(databaseProvider).updatePhaseTtsProject(result);
  }

  Future<void> _editSegmentText(db.PhaseTtsSegment segment, String text) async {
    // The old take no longer matches the words; drop the link so the
    // segment shows up as pending again (the file itself stays on disk).
    await ref
        .read(databaseProvider)
        .updatePhaseTtsSegment(
          segment.copyWith(
            segmentText: text,
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
            missing: false,
          ),
        );
    _markDirty();
  }

  Future<void> _normalizeLoudness(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
  ) async {
    await runLoudnessNormalization(
      context: context,
      ref: ref,
      bankId: project.bankId,
      items: [
        for (final s in segments)
          if (s.audioPath != null && !s.missing)
            LoudnessItem(
              id: s.id,
              path: s.audioPath!,
              voiceAssetId: s.voiceAssetId,
            ),
      ],
    );
  }

  void _markDirty() {
    if (_dirty || !mounted) return;
    _update(() => _dirty = true);
  }

  Future<void> _saveProject(db.PhaseTtsProject project) async {
    await _pendingScriptWrite;
    await ref
        .read(databaseProvider)
        .updatePhaseTtsProject(
          project.copyWith(
            scriptText: _scriptController.text,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    _update(() => _dirty = false);
    _showSnack(AppLocalizations.of(context).uiSaved);
  }

  Future<bool> _back(db.PhaseTtsProject project) async {
    final canLeave = await _confirmLeave(project);
    if (canLeave && mounted) {
      _update(() {
        _selectedProjectId = null;
        _dirty = false;
      });
    }
    return canLeave;
  }

  Future<bool> _confirmLeaveActiveProject() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return true;
    final project = await ref
        .read(databaseProvider)
        .getPhaseTtsProjectById(projectId);
    if (project == null) return true;
    return _confirmLeave(project);
  }

  Future<void> _backActiveProject() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return;
    final project = await ref
        .read(databaseProvider)
        .getPhaseTtsProjectById(projectId);
    if (project == null) {
      if (mounted) _update(() => _selectedProjectId = null);
      return;
    }
    await _back(project);
  }

  Future<bool> _confirmLeave(db.PhaseTtsProject project) async {
    if (!_dirty) return true;
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
            child: Text(AppLocalizations.of(context).uiDontSave),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(AppLocalizations.of(context).uiSaveLeave),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _saveProject(project);
      return true;
    }
    return choice == 'discard';
  }

  void _playSegment(
    db.PhaseTtsSegment seg,
    int index,
    List<db.VoiceAsset> bankAssets,
  ) {
    if (seg.audioPath == null || !File(seg.audioPath!).existsSync()) return;
    final voiceName =
        bankAssets.where((a) => a.id == seg.voiceAssetId).firstOrNull?.name ??
        'Segment ${index + 1}';
    ref
        .read(playbackNotifierProvider.notifier)
        .load(
          seg.audioPath!,
          seg.segmentText,
          subtitle: voiceName,
          sourceTag: phaseTtsPlaybackSource,
        );
  }

  Future<void> _playAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final ordered = [...segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final assetMap = {for (final asset in bankAssets) asset.id: asset};
    final items = [
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].audioPath != null &&
            !ordered[i].missing &&
            File(ordered[i].audioPath!).existsSync())
          (
            audioPath: ordered[i].audioPath!,
            title: ordered[i].segmentText,
            subtitle:
                assetMap[ordered[i].voiceAssetId]?.name ?? 'Segment ${i + 1}',
          ),
    ];
    if (items.isEmpty) {
      _showSnack(AppLocalizations.of(context).phaseNoAudioToPlay);
      return;
    }
    await ref
        .read(playbackNotifierProvider.notifier)
        .playSequenceFrom(
          items,
          sourceTag: phaseTtsPlaybackSource,
          gap: Duration(milliseconds: (project.mergeGapSeconds * 1000).round()),
        );
  }
}
