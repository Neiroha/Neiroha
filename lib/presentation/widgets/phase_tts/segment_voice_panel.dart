import 'package:neiroha/domain/text/semantic_split.dart';
import 'package:neiroha/presentation/widgets/live_sentence_preview_button.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'speaker_label.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/domain/voice_capabilities.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'segment_card.dart';
part 'segment_card_parts.dart';
part 'segment_dialogs.dart';
part 'segment_panel_actions.dart';
part 'segment_panel_bars.dart';

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

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

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
}

bool _hasAudio(db.PhaseTtsSegment segment) =>
    segment.audioPath != null && !segment.missing;

enum _SegmentFilter { all, pending, done, failed }

enum _SegmentStatus { pending, generating, done, failed }

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
