part of 'editor.dart';

extension _VideoDubEditorSubtitleActions on _VideoDubEditorState {
  Future<void> _importSubtitles(
    db.VideoDubProject project,
    List<db.SubtitleCue> existing,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'lrc', 'vtt', 'txt'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;

    List<ParsedCue> parsed;
    try {
      parsed = await SubtitleParser.parseFile(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Parse failed: $e')));
      }
      return;
    }
    if (parsed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No cues found in file')));
      }
      return;
    }

    if (!mounted) return;
    final choice = await showImportSubtitlesDialog(
      context: context,
      cueCount: parsed.length,
      existingCount: existing.length,
      initialAutoTts: _autoTtsAfterImport,
      initialAutoSync: _autoSyncAfterImport,
    );
    if (choice == null) return;

    // Persist switch state across imports in this session.
    _autoTtsAfterImport = choice.autoTts;
    _autoSyncAfterImport = choice.autoSync;

    final database = ref.read(databaseProvider);
    _markDirty();
    int nextOrder = 0;
    if (choice.replace) {
      await database.clearSubtitleCues(project.id);
    } else {
      nextOrder = existing.isEmpty
          ? 0
          : (existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) +
                1);
    }
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    final members =
        ref.read(bankMembersStreamProvider(project.bankId)).valueOrNull ??
        const <db.VoiceBankMember>[];
    // Default voice = first voice in this project's bank.
    String? defaultVoiceId;
    if (members.isNotEmpty && banks.isNotEmpty) {
      defaultVoiceId = members.first.voiceAssetId;
    }

    for (var i = 0; i < parsed.length; i++) {
      final c = parsed[i];
      await database.insertSubtitleCue(
        db.SubtitleCuesCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(project.id),
          orderIndex: Value(nextOrder + i),
          startMs: Value(c.startMs),
          endMs: Value(c.endMs),
          cueText: Value(c.text),
          voiceAssetId: Value(defaultVoiceId),
        ),
      );
    }
    await database.updateVideoDubProject(
      project.copyWith(updatedAt: DateTime.now()),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Imported ${parsed.length} cues')));
    }

    // Auto-flow: re-read cues from the database (the freshly-inserted
    // rows aren't in `existing`), then optionally generate then sync.
    if (!choice.autoTts && !choice.autoSync) return;
    final fresh = await database.getSubtitleCues(project.id);
    if (choice.autoTts) {
      final bankAssets = await _resolveBankAssets(project.bankId);
      if (bankAssets.isEmpty) {
        if (mounted) {
          _snack('Auto-TTS skipped — bank has no voices');
        }
      } else {
        await _runGenerateAll(project, fresh, bankAssets, forceRegen: false);
      }
    }
    if (choice.autoSync) {
      // Re-read again post-generation so audioDuration is populated.
      final afterGen = await database.getSubtitleCues(project.id);
      await _syncCueLengthsToAudio(afterGen);
    }
  }

  /// Resolve the [bankId]'s voice assets the same way the editor build
  /// does — needed for the auto-TTS path because that fires from inside
  /// `_importSubtitles`, not from the build closure.
  Future<List<db.VoiceAsset>> _resolveBankAssets(String bankId) async {
    final db_ = ref.read(databaseProvider);
    final members = await db_.getBankMembers(bankId);
    final allAssets = await db_.getAllVoiceAssets();
    final assetMap = {for (final a in allAssets) a.id: a};
    return members
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();
  }

  Future<void> _addCueDialog(
    db.VideoDubProject project,
    List<db.SubtitleCue> existing,
  ) async {
    // Resolve the bank's voices straight from the DB — works even on
    // first build before the stream provider has had a chance to warm.
    final bankAssets = await _resolveBankAssets(project.bankId);
    // Default to the first voice if there is one, mirroring what the
    // SRT-import path does.
    final initialVoiceId = bankAssets.isEmpty ? null : bankAssets.first.id;

    if (!mounted) return;
    final result = await showCueEditDialog(
      context: context,
      initialStartMs: _position.inMilliseconds,
      initialEndMs: _position.inMilliseconds + 3000,
      initialText: '',
      title: 'Add cue',
      showAutoSwitches: true,
      initialAutoTts: _autoTtsAfterImport,
      initialAutoSync: _autoSyncAfterImport,
      voiceAssets: bankAssets,
      initialVoiceId: initialVoiceId,
    );
    if (result == null) return;

    // Persist the user's choice for next time.
    _autoTtsAfterImport = result.autoTts;
    _autoSyncAfterImport = result.autoSync;

    final nextOrder = existing.isEmpty
        ? 0
        : (existing.map((c) => c.orderIndex).reduce((a, b) => a > b ? a : b) +
              1);
    // Prefer the dropdown choice; fall back to the first bank voice if
    // somehow nothing came back.
    final voiceForCue = result.voiceAssetId ?? initialVoiceId;
    final cueId = const Uuid().v4();
    final database = ref.read(databaseProvider);
    await database.insertSubtitleCue(
      db.SubtitleCuesCompanion(
        id: Value(cueId),
        projectId: Value(project.id),
        orderIndex: Value(nextOrder),
        startMs: Value(result.startMs),
        endMs: Value(result.endMs),
        cueText: Value(result.text),
        voiceAssetId: Value(voiceForCue),
      ),
    );
    _markDirty();

    if (!result.autoTts && !result.autoSync) return;

    // Re-read the row from the DB so we have a real `SubtitleCue` (not
    // a companion) to feed `_generateOne`. Same pattern the bulk-import
    // auto-flow uses.
    final allCues = await database.getSubtitleCues(project.id);
    final fresh = allCues.where((c) => c.id == cueId).firstOrNull;
    if (fresh == null) return;

    if (result.autoTts) {
      if (fresh.voiceAssetId == null || bankAssets.isEmpty) {
        if (mounted) _snack('Auto-TTS skipped — bank has no voices');
      } else {
        // Reuse the bank list we resolved before opening the dialog —
        // no second round-trip to the DB.
        await _generateOne(project, fresh, bankAssets);
      }
    }

    if (result.autoSync) {
      // _generateOne writes audioDuration on success — re-read so we
      // pick that up before snapping endMs.
      final afterGen = await database.getSubtitleCues(project.id);
      final updated = afterGen.where((c) => c.id == cueId).firstOrNull;
      if (updated != null && updated.audioDuration != null) {
        final newEnd =
            updated.startMs + (updated.audioDuration! * 1000).round();
        if (newEnd != updated.endMs) {
          await database.updateSubtitleCue(updated.copyWith(endMs: newEnd));
        }
      }
    }
  }

  Future<void> _editCueDialog(db.SubtitleCue cue) async {
    final result = await showCueEditDialog(
      context: context,
      initialStartMs: cue.startMs,
      initialEndMs: cue.endMs,
      initialText: cue.cueText,
      title: 'Edit cue',
    );
    if (result == null) return;
    _markDirty();
    await ref
        .read(databaseProvider)
        .updateSubtitleCue(
          cue.copyWith(
            startMs: result.startMs,
            endMs: result.endMs,
            cueText: result.text,
            // Edits invalidate the old audio.
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
          ),
        );
  }

  Future<void> _confirmClearCues(db.VideoDubProject project) async {
    final confirmed = await showClearCuesConfirmDialog(context);
    if (confirmed) {
      await ref.read(databaseProvider).clearSubtitleCues(project.id);
      _markDirty();
    }
  }

  Future<void> _deleteCue(db.SubtitleCue cue) async {
    if (_selectedCueId == cue.id) {
      _updateState(() => _selectedCueId = null);
    }
    await ref.read(databaseProvider).deleteSubtitleCue(cue.id);
    _markDirty();
  }

  void _updateCueVoice(db.SubtitleCue cue, String? voiceId) {
    ref
        .read(databaseProvider)
        .updateSubtitleCue(cue.copyWith(voiceAssetId: Value(voiceId)));
    _markDirty();
  }

  Future<void> _previewCue(db.SubtitleCue cue) async {
    if (cue.audioPath == null) return;
    if (_previewCueId == cue.id) {
      await _previewPlayer.stop();
      _updateState(() => _previewCueId = null);
      return;
    }
    _updateState(() => _previewCueId = cue.id);
    await _previewPlayer.open(Media(cue.audioPath!), play: true);
  }
}
