part of 'segment_voice_panel.dart';

/// Style settings file, segment actions and keyboard navigation.
extension _SegmentPanelActions on _SegmentVoicePanelState {
  // ───────────────────────── Style settings file ─────────────────────────

  Future<void> _loadSettings() async {
    final slug = await _ensureProjectSlug();
    final settings = await _settingsService.load(slug);
    if (!mounted) return;
    _update(() => _settings = settings);
  }

  Future<String> _ensureProjectSlug() async {
    final existing = _projectSlug;
    if (existing != null) return existing;
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(widget.project.id);
    if (mounted) _update(() => _projectSlug = slug);
    return slug;
  }

  void _setSegmentSettings(
    String segmentId,
    SegmentVoiceSettings settings, {
    bool saveNow = false,
  }) {
    final next = Map<String, SegmentVoiceSettings>.from(_settings.bySegmentId);
    if (settings.isEmpty) {
      next.remove(segmentId);
    } else {
      next[segmentId] = settings;
    }
    widget.onChanged();
    _update(() => _settings = _settings.copyWith(bySegmentId: next));
    if (saveNow) {
      _saveTimer?.cancel();
      unawaited(_saveSettings());
    } else {
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveSettings());
    });
  }

  Future<void> _saveSettings() {
    final service = _settingsService;
    final settings = _settings;
    _pendingSave = _pendingSave.catchError((_) {}).then((_) async {
      final slug = await _ensureProjectSlug();
      await service.save(slug, settings);
    });
    return _pendingSave.then((_) {});
  }

  /// Settings must be on disk before the screen reads them for a request.
  Future<void> _flushSettings() async {
    _saveTimer?.cancel();
    await _saveSettings();
  }

  // ───────────────────────── Voice changes ─────────────────────────

  db.TtsProvider? _providerFor(db.VoiceAsset? asset) {
    if (asset == null) return null;
    final providers = ref.read(ttsProvidersStreamProvider).value ?? [];
    return providers.where((p) => p.id == asset.providerId).firstOrNull;
  }

  /// Drop style fields the newly chosen voice's engine can't use.
  SegmentVoiceSettings _pruneFor(
    SegmentVoiceSettings current,
    String? voiceAssetId,
  ) {
    final asset = widget.bankAssets
        .where((a) => a.id == voiceAssetId)
        .firstOrNull;
    final provider = _providerFor(asset);
    final keepInstruction =
        asset != null &&
        provider != null &&
        VoiceCapabilities.supportsVoiceInstruction(asset, provider);
    final keepAudioTag =
        asset != null &&
        provider != null &&
        VoiceCapabilities.supportsAudioTags(asset, provider);
    return SegmentVoiceSettings(
      voiceInstruction: keepInstruction ? current.voiceInstruction : null,
      audioTagPrefix: keepAudioTag ? current.audioTagPrefix : null,
    );
  }

  Future<void> _applyBulkVoice(List<db.PhaseTtsSegment> segments) async {
    await widget.onApplyVoiceToAll(_bulkVoiceId);
    if (_settings.bySegmentId.isEmpty) return;
    final next = Map<String, SegmentVoiceSettings>.from(_settings.bySegmentId);
    for (final segment in segments) {
      final current = next[segment.id];
      if (current == null || current.isEmpty) continue;
      final pruned = _pruneFor(current, _bulkVoiceId);
      if (pruned.isEmpty) {
        next.remove(segment.id);
      } else {
        next[segment.id] = pruned;
      }
    }
    _update(() => _settings = _settings.copyWith(bySegmentId: next));
    await _saveSettings();
  }

  void _changeSegmentVoice(db.PhaseTtsSegment segment, String? voiceAssetId) {
    widget.onVoiceChanged(segment, voiceAssetId);
    final current = _settings.bySegmentId[segment.id];
    if (current == null || current.isEmpty) return;
    _setSegmentSettings(
      segment.id,
      _pruneFor(current, voiceAssetId),
      saveNow: true,
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _generateSegment(db.PhaseTtsSegment segment) async {
    await _flushSettings();
    await widget.onGenerate?.call(segment);
  }

  Future<void> _generateMany(List<db.PhaseTtsSegment> segments) async {
    if (segments.isEmpty) return;
    await _flushSettings();
    widget.onGenerateMany?.call(segments);
  }

  Future<void> _togglePlay(db.PhaseTtsSegment segment, int index) async {
    final playback = ref.read(playbackNotifierProvider);
    if (playback.isPlaying && playback.audioPath == segment.audioPath) {
      await ref.read(playbackNotifierProvider.notifier).stop();
      return;
    }
    widget.onPlay(segment, index);
  }

  void _focusSegment(db.PhaseTtsSegment segment, {bool reveal = true}) {
    _update(() => _focusedId = segment.id);
    _focusNode.requestFocus();
    if (reveal) widget.onReveal(segment);
  }

  void _toggleSelected(String id) {
    _update(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _setSelecting(bool value) {
    _update(() {
      _selecting = value;
      _selected.clear();
    });
    _focusNode.requestFocus();
  }

  void _delete(List<db.PhaseTtsSegment> segments) {
    if (segments.isEmpty) return;
    _update(() {
      _selected.removeAll(segments.map((s) => s.id));
      if (segments.any((s) => s.id == _focusedId)) _focusedId = null;
    });
    // Style settings stay in the file so an undo brings them back.
    widget.onDelete(segments);
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  void _reorder(List<db.PhaseTtsSegment> ordered, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final ids = ordered.map((s) => s.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _update(() => _localOrder = ids);
    widget.onReorder(oldIndex, newIndex);
  }

  bool _matchesFilter(db.PhaseTtsSegment segment) => switch (_filter) {
    _SegmentFilter.all => true,
    _SegmentFilter.pending => !_hasAudio(segment),
    _SegmentFilter.done => _hasAudio(segment),
    _SegmentFilter.failed => segment.error != null,
  };

  List<db.PhaseTtsSegment> _ordered() {
    final ordered = [...widget.segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final local = _localOrder;
    if (local == null || local.length != ordered.length) return ordered;
    final byId = {for (final s in ordered) s.id: s};
    if (!local.every(byId.containsKey)) return ordered;
    return [for (final id in local) byId[id]!];
  }

  // ───────────────────────── Keyboard ─────────────────────────

  /// ↑/↓ move focus · Space play/stop · Enter generate · F2 edit · Delete remove ·
  /// Esc leave multi-select or clear focus · Ctrl+A select all (multi-select).
  KeyEventResult _onKey(
    FocusNode node,
    KeyEvent event,
    List<db.PhaseTtsSegment> ordered,
    List<int> visible,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final focusedIndex = ordered.indexWhere((s) => s.id == _focusedId);
    final focused = focusedIndex < 0 ? null : ordered[focusedIndex];

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (visible.isEmpty) return KeyEventResult.handled;
      final pos = visible.indexOf(focusedIndex);
      final down = key == LogicalKeyboardKey.arrowDown;
      final nextPos = pos < 0
          ? (down ? 0 : visible.length - 1)
          : (pos + (down ? 1 : -1)).clamp(0, visible.length - 1);
      final next = ordered[visible[nextPos]];
      _focusSegment(next);
      _ensureVisible(next.id, visible[nextPos]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_selecting) {
        _setSelecting(false);
      } else {
        _update(() => _focusedId = null);
      }
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyA && _selecting) {
      _update(() => _selected.addAll(visible.map((i) => ordered[i].id)));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      if (_selecting && _selected.isNotEmpty) {
        _delete([
          for (final s in ordered)
            if (_selected.contains(s.id)) s,
        ]);
      } else if (focused != null) {
        _delete([focused]);
      }
      return KeyEventResult.handled;
    }
    if (focused == null) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.space) {
      if (_hasAudio(focused)) unawaited(_togglePlay(focused, focusedIndex));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_canGenerate(focused)) unawaited(_generateSegment(focused));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      unawaited(_openEditTextDialog(focused));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _ensureVisible(String id, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cardKeys[id]?.currentContext;
      if (ctx != null) {
        unawaited(
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 160),
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
        );
        return;
      }
      // Not built yet (far off-screen): jump close, then align.
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        (index * 118.0).clamp(0.0, position.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final again = _cardKeys[id]?.currentContext;
        if (again != null) {
          unawaited(Scrollable.ensureVisible(again, alignment: 0.3));
        }
      });
    });
  }

  bool _canGenerate(db.PhaseTtsSegment segment) =>
      segment.voiceAssetId != null &&
      !widget.generatingSegmentIds.contains(segment.id) &&
      widget.onGenerate != null;
}
