import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/domain/voice_capabilities.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'segment_card.dart';
part 'segment_dialogs.dart';

/// Right-side sentence list for Phase TTS.
///
/// Header with progress stats, a wrapping action toolbar, status filters and
/// one card per sentence. Cards can be reordered by their drag handle,
/// selected in bulk, split / merged / inserted, and driven from the
/// keyboard (see [_onKey]). Structural edits go through callbacks so the
/// screen owns persistence and undo.
class SegmentVoicePanel extends ConsumerStatefulWidget {
  final db.PhaseTtsProject project;
  final List<db.PhaseTtsSegment> segments;
  final List<db.VoiceAsset> bankAssets;
  final Set<String> generatingSegmentIds;
  final Future<void> Function(String? voiceAssetId) onApplyVoiceToAll;
  final void Function(db.PhaseTtsSegment segment, String? voiceAssetId)
  onVoiceChanged;
  final void Function(db.PhaseTtsSegment segment, int index) onPlay;
  final Future<void> Function(db.PhaseTtsSegment segment)? onGenerate;

  /// Regenerate the given segments (selection, failed retries).
  final void Function(List<db.PhaseTtsSegment> segments)? onGenerateMany;

  /// Non-null while a batch generation can be stopped.
  final VoidCallback? onCancelGenerate;
  final void Function(List<db.PhaseTtsSegment> segments) onDelete;
  final Future<void> Function(db.PhaseTtsSegment segment, String text)
  onEditText;
  final Future<void> Function(
    db.PhaseTtsSegment segment,
    String head,
    String tail,
  )
  onSplit;
  final Future<void> Function(db.PhaseTtsSegment segment) onMergeNext;

  /// Insert [text] after [after] (at the top when null).
  final Future<void> Function(db.PhaseTtsSegment? after, String text)
  onInsertAfter;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Highlight the segment in the script editor.
  final ValueChanged<db.PhaseTtsSegment> onReveal;
  final VoidCallback onChanged;
  final VoidCallback onPlayAll;
  final VoidCallback onGenerateAll;
  final VoidCallback? onNormalize;
  final bool generatingAll;

  const SegmentVoicePanel({
    super.key,
    required this.project,
    required this.segments,
    required this.bankAssets,
    required this.generatingSegmentIds,
    required this.onApplyVoiceToAll,
    required this.onVoiceChanged,
    required this.onPlay,
    required this.onGenerate,
    required this.onGenerateMany,
    required this.onCancelGenerate,
    required this.onDelete,
    required this.onEditText,
    required this.onSplit,
    required this.onMergeNext,
    required this.onInsertAfter,
    required this.onReorder,
    required this.onReveal,
    required this.onChanged,
    required this.onPlayAll,
    required this.onGenerateAll,
    required this.onNormalize,
    required this.generatingAll,
  });

  @override
  ConsumerState<SegmentVoicePanel> createState() => _SegmentVoicePanelState();
}

class _SegmentVoicePanelState extends ConsumerState<SegmentVoicePanel> {
  String? _bulkVoiceId;
  _SegmentFilter _filter = _SegmentFilter.all;
  PhaseSegmentSettings _settings = const PhaseSegmentSettings();
  String? _projectSlug;
  Timer? _saveTimer;
  Future<dynamic> _pendingSave = Future<dynamic>.value();

  bool _selecting = false;
  final Set<String> _selected = <String>{};
  String? _focusedId;

  /// Optimistic order after a drag, until the database stream catches up.
  List<String>? _localOrder;

  final FocusNode _focusNode = FocusNode(debugLabel: 'phase-segments');
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  // Cached during initState — `ref.read` is unsafe in dispose() because
  // ConsumerStatefulElement is already torn down by then. The service object
  // itself lives in the enclosing ProviderScope, so calling it post-dispose
  // is fine.
  late final PhaseSegmentSettingsFileService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = ref.read(phaseSegmentSettingsFileServiceProvider);
    unawaited(_loadSettings());
  }

  @override
  void didUpdateWidget(covariant SegmentVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _settings = const PhaseSegmentSettings();
      _bulkVoiceId = null;
      _projectSlug = null;
      _selected.clear();
      _focusedId = null;
      unawaited(_loadSettings());
    }
    if (!identical(oldWidget.segments, widget.segments)) {
      _localOrder = null;
      final ids = widget.segments.map((s) => s.id).toSet();
      _selected.removeWhere((id) => !ids.contains(id));
      if (_focusedId != null && !ids.contains(_focusedId)) _focusedId = null;
      _cardKeys.removeWhere((id, _) => !ids.contains(id));
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final slug = _projectSlug;
    if (slug != null) {
      final service = _settingsService;
      final settings = _settings;
      unawaited(
        _pendingSave
            .catchError((_) {})
            .then((_) => service.save(slug, settings)),
      );
    }
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ───────────────────────── Style settings file ─────────────────────────

  Future<void> _loadSettings() async {
    final slug = await _ensureProjectSlug();
    final settings = await _settingsService.load(slug);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<String> _ensureProjectSlug() async {
    final existing = _projectSlug;
    if (existing != null) return existing;
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(widget.project.id);
    if (mounted) setState(() => _projectSlug = slug);
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
    setState(() => _settings = _settings.copyWith(bySegmentId: next));
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
    setState(() => _settings = _settings.copyWith(bySegmentId: next));
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
    setState(() => _focusedId = segment.id);
    _focusNode.requestFocus();
    if (reveal) widget.onReveal(segment);
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _setSelecting(bool value) {
    setState(() {
      _selecting = value;
      _selected.clear();
    });
    _focusNode.requestFocus();
  }

  void _delete(List<db.PhaseTtsSegment> segments) {
    if (segments.isEmpty) return;
    setState(() {
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
    setState(() => _localOrder = ids);
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
        setState(() => _focusedId = null);
      }
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyA && _selecting) {
      setState(() => _selected.addAll(visible.map((i) => ordered[i].id)));
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

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordered = _ordered();
    final doneCount = ordered.where(_hasAudio).length;
    final failed = ordered.where((s) => s.error != null).toList();
    final pendingCount = ordered.length - doneCount;
    final unassignedCount = ordered.where((s) => s.voiceAssetId == null).length;
    final queuedCount = ordered
        .where((s) => !_hasAudio(s) && s.voiceAssetId != null)
        .length;
    final totalSeconds = ordered
        .where(_hasAudio)
        .fold<double>(0, (sum, s) => sum + (s.audioDuration ?? 0));
    // Only rebuild on play/stop transitions, not on every position tick.
    final playingPath = ref.watch(
      playbackNotifierProvider.select((s) => s.isPlaying ? s.audioPath : null),
    );
    final visible = [
      for (var i = 0; i < ordered.length; i++)
        if (_matchesFilter(ordered[i])) i,
    ];
    final reorderable =
        _filter == _SegmentFilter.all && !_selecting && ordered.length > 1;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _onKey(node, event, ordered, visible),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            total: ordered.length,
            done: doneCount,
            failed: failed.length,
            unassigned: unassignedCount,
            totalSeconds: totalSeconds,
          ),
          if (_selecting)
            _buildSelectionBar(l10n, ordered, visible)
          else
            _buildToolbar(
              l10n,
              ordered,
              doneCount: doneCount,
              queuedCount: queuedCount,
              failed: failed,
            ),
          if (ordered.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  for (final filter in _SegmentFilter.values) ...[
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(switch (filter) {
                        _SegmentFilter.all =>
                          '${l10n.phaseFilterAll} ${ordered.length}',
                        _SegmentFilter.pending =>
                          '${l10n.phaseFilterPending} $pendingCount',
                        _SegmentFilter.done =>
                          '${l10n.phaseFilterDone} $doneCount',
                        _SegmentFilter.failed =>
                          '${l10n.phaseFilterFailed} ${failed.length}',
                      }),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ordered.isEmpty
                ? _EmptyState(
                    text: l10n.uiRunAutoSplitToCreateSegments,
                    action: TextButton.icon(
                      onPressed: () => unawaited(_openInsertDialog(null)),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l10n.phaseAddSegment),
                    ),
                  )
                : visible.isEmpty
                ? _EmptyState(text: l10n.phaseNoFilterMatches)
                : reorderable
                ? ReorderableListView.builder(
                    scrollController: _scrollController,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.all(8),
                    itemCount: ordered.length,
                    onReorderItem: (o, n) => _reorder(ordered, o, n),
                    proxyDecorator: (child, _, _) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, index) => _buildCard(
                      ordered,
                      index,
                      playingPath,
                      dragIndex: index,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: visible.length,
                    itemBuilder: (context, i) =>
                        _buildCard(ordered, visible[i], playingPath),
                  ),
          ),
          const PersistentAudioBar(onlyForSourceTag: phaseTtsPlaybackSource),
        ],
      ),
    );
  }

  Widget _buildCard(
    List<db.PhaseTtsSegment> ordered,
    int index,
    String? playingPath, {
    int? dragIndex,
  }) {
    final segment = ordered[index];
    final generating = widget.generatingSegmentIds.contains(segment.id);
    return _SegmentCard(
      key: _cardKeys.putIfAbsent(segment.id, () => GlobalKey()),
      segment: segment,
      index: index,
      isLast: index == ordered.length - 1,
      assets: widget.bankAssets,
      settings: _settings.bySegmentId[segment.id],
      isGenerating: generating,
      isPlaying: playingPath != null && playingPath == segment.audioPath,
      focused: segment.id == _focusedId,
      selecting: _selecting,
      selected: _selected.contains(segment.id),
      dragIndex: dragIndex,
      onTap: () =>
          _selecting ? _toggleSelected(segment.id) : _focusSegment(segment),
      onVoiceChanged: (id) => _changeSegmentVoice(segment, id),
      onSettings: () => _openSettingsDialog(segment),
      onEditText: () => _openEditTextDialog(segment),
      onSplit: () => _openSplitDialog(segment),
      onMergeNext: () => unawaited(widget.onMergeNext(segment)),
      onInsertBelow: () => unawaited(_openInsertDialog(segment)),
      onTogglePlay: () => _togglePlay(segment, index),
      onDelete: () => _delete([segment]),
      onGenerate: _canGenerate(segment)
          ? () => unawaited(_generateSegment(segment))
          : null,
    );
  }

  Widget _buildToolbar(
    AppLocalizations l10n,
    List<db.PhaseTtsSegment> ordered, {
    required int doneCount,
    required int queuedCount,
    required List<db.PhaseTtsSegment> failed,
  }) {
    final assetIds = widget.bankAssets.map((asset) => asset.id).toSet();
    final bulkValue = _bulkVoiceId != null && assetIds.contains(_bulkVoiceId)
        ? _bulkVoiceId
        : null;
    final canGenerateAll =
        queuedCount > 0 &&
        widget.bankAssets.isNotEmpty &&
        !widget.generatingAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.generatingAll)
                FilledButton.tonalIcon(
                  onPressed: widget.onCancelGenerate,
                  icon: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text(l10n.phaseStopGenerating),
                )
              else
                FilledButton.icon(
                  onPressed: canGenerateAll ? widget.onGenerateAll : null,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(
                    queuedCount > 0
                        ? l10n.uiGenerateAll2(queuedCount)
                        : l10n.uiGenerateAll,
                  ),
                ),
              if (failed.isNotEmpty && !widget.generatingAll)
                OutlinedButton.icon(
                  onPressed: widget.onGenerateMany == null
                      ? null
                      : () => unawaited(
                          _generateMany(
                            failed
                                .where((s) => s.voiceAssetId != null)
                                .toList(),
                          ),
                        ),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(l10n.phaseRetryFailed(failed.length)),
                ),
              OutlinedButton.icon(
                onPressed: doneCount > 0 ? widget.onPlayAll : null,
                icon: const Icon(Icons.playlist_play_rounded, size: 18),
                label: Text(l10n.phasePlayAll),
              ),
              Tooltip(
                message: l10n.loudnessActionTooltip,
                child: OutlinedButton.icon(
                  onPressed: doneCount > 0 ? widget.onNormalize : null,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 16),
                  label: Text(l10n.loudnessAction),
                ),
              ),
              IconButton(
                tooltip: l10n.phaseSelectMode,
                onPressed: ordered.isEmpty ? null : () => _setSelecting(true),
                icon: const Icon(Icons.checklist_rounded, size: 20),
              ),
              IconButton(
                tooltip: l10n.phaseAddSegment,
                onPressed: () => unawaited(
                  _openInsertDialog(ordered.isEmpty ? null : ordered.last),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: _VoiceDropdown(
                    value: bulkValue,
                    assets: widget.bankAssets,
                    hintText: l10n.uiVoiceForAll,
                    onChanged: (id) => setState(() => _bulkVoiceId = id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: ordered.isEmpty
                    ? null
                    : () => unawaited(_applyBulkVoice(ordered)),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: Text(l10n.phaseApplyVoiceToAll),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(
    AppLocalizations l10n,
    List<db.PhaseTtsSegment> ordered,
    List<int> visible,
  ) {
    final chosen = [
      for (final s in ordered)
        if (_selected.contains(s.id)) s,
    ];
    final none = chosen.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Text(
            l10n.phaseSelectedCount(chosen.length),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => setState(
              () => _selected.addAll(visible.map((i) => ordered[i].id)),
            ),
            child: Text(l10n.phaseSelectAll),
          ),
          PopupMenuButton<String>(
            enabled: !none,
            tooltip: l10n.phaseAssignVoice,
            onSelected: (id) {
              final voiceId = id.isEmpty ? null : id;
              for (final s in chosen) {
                _changeSegmentVoice(s, voiceId);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: '', child: Text(l10n.uiUnassigned)),
              for (final a in widget.bankAssets)
                PopupMenuItem(value: a.id, child: Text(a.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: none ? Colors.white24 : AppTheme.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.phaseAssignVoice,
                    style: TextStyle(
                      fontSize: 13,
                      color: none ? Colors.white38 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.phaseRegenerateSelected,
            onPressed: none || widget.onGenerateMany == null
                ? null
                : () => unawaited(
                    _generateMany(
                      chosen.where((s) => s.voiceAssetId != null).toList(),
                    ),
                  ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          IconButton(
            tooltip: l10n.phaseDeleteSelected,
            onPressed: none ? null : () => _delete(chosen),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: _failedColor,
            ),
          ),
          IconButton(
            tooltip: l10n.phaseExitSelect,
            onPressed: () => _setSelecting(false),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

bool _hasAudio(db.PhaseTtsSegment segment) =>
    segment.audioPath != null && !segment.missing;

enum _SegmentFilter { all, pending, done, failed }

enum _SegmentStatus { pending, generating, done, failed }

const _doneColor = Color(0xFF4ADE80);
const _failedColor = Color(0xFFF87171);

class _PanelHeader extends StatelessWidget {
  final int total;
  final int done;
  final int failed;
  final int unassigned;
  final double totalSeconds;

  const _PanelHeader({
    required this.total,
    required this.done,
    required this.failed,
    required this.unassigned,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Colors.white.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.uiSEGMENTS,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      l10n.phaseStatsGenerated(done, total),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    if (totalSeconds > 0)
                      Text(
                        _formatClock(totalSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (failed > 0)
                      Text(
                        l10n.phaseStatsFailed(failed),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _failedColor,
                        ),
                      ),
                    if (unassigned > 0)
                      Text(
                        l10n.phaseStatsUnassigned(unassigned),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.phaseShortcuts,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.keyboard_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  color: done == total ? _doneColor : AppTheme.accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatClock(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  final clock = '$mm:${s.toString().padLeft(2, '0')}';
  return h > 0 ? '$h:$clock' : clock;
}

String _formatShort(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
  return _formatClock(seconds);
}

/// Split point near the middle of [text], preferring sentence punctuation.
int _suggestSplitOffset(String text) {
  final middle = text.length ~/ 2;
  final marks = RegExp(r'[。！？!?；;，,、…]');
  var best = -1;
  for (final m in marks.allMatches(text)) {
    final at = m.end;
    if (at <= 0 || at >= text.length) continue;
    if (best < 0 || (at - middle).abs() < (best - middle).abs()) best = at;
  }
  return best < 0 ? math.max(1, middle) : best;
}
