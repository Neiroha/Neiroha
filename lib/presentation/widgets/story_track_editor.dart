import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart' as db;
import '../../providers/app_providers.dart';
import '../../providers/playback_provider.dart';
import '../theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Payload carried by draggable segment cards / chat bubbles when dropped
/// onto the story timeline. The timeline inserts a new clip using these fields.
class TimelineDropPayload {
  final String audioPath;
  final String label;
  final double? durationSec;
  final String? sourceLineId;

  const TimelineDropPayload({
    required this.audioPath,
    required this.label,
    this.durationSec,
    this.sourceLineId,
  });
}

/// A small icon button that doubles as a drag source for the timeline.
/// Tap inserts at the anchor (via [onTap]); dragging starts a
/// [Draggable]<[TimelineDropPayload]> that the timeline's [DragTarget]
/// accepts and places at the drop location.
class TimelineDragButton extends StatelessWidget {
  final TimelineDropPayload? payload;
  final VoidCallback? onTap;
  final bool enabled;

  const TimelineDragButton({
    super.key,
    required this.payload,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.playlist_add_rounded,
      size: 18,
      color: enabled
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.15),
    );
    final button = IconButton(
      icon: icon,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: AppLocalizations.of(context).uiAddToTimelineDragToPlace,
      onPressed: enabled ? onTap : null,
    );
    if (!enabled || payload == null) return button;
    return Draggable<TimelineDropPayload>(
      data: payload!,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            payload!.label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: button,
    );
  }
}

/// Multi-lane editable timeline backed by the `TimelineClips` table.
/// Clips are positioned by `startTimeMs` and `laneIndex`, independent of the
/// source line order. Supports horizontal drag to reposition, vertical drag
/// to change lane, tap to select, and delete of selected clip.
class StoryTrackEditor extends ConsumerStatefulWidget {
  final String projectId;
  final String projectType; // 'dialog' | 'phase'
  final String projectName;

  const StoryTrackEditor({
    super.key,
    required this.projectId,
    required this.projectType,
    required this.projectName,
  });

  @override
  ConsumerState<StoryTrackEditor> createState() => _StoryTrackEditorState();
}

class _StoryTrackEditorState extends ConsumerState<StoryTrackEditor> {
  double _pixelsPerSecond = 50.0;
  final _scrollController = ScrollController();
  static const double _laneHeight = 52.0;
  static const double _rulerHeight = 18.0;
  static const double _topHandleHeight = 6.0;

  String? _selectedClipId;
  // In-flight clip drag state (null when not dragging).
  String? _dragClipId;
  int? _dragStartMs;
  int? _dragLane;
  // Accumulated Y offset from pan start — needed because per-frame
  // details.delta.dy values round to 0 against a 52px lane step.
  double _dragCumulativeDy = 0;
  int? _dragOriginLane;

  // ID of the clip currently emitting audio during Play All. Tracking by id
  // (not audioPath) keeps the playhead glued to the right clip when two
  // clips share the same underlying file.
  String? _activeClipId;

  // Extra vertical space added by dragging the top resize handle.
  double _extraHeight = 0;

  // Seek anchor — the playhead's "home" position in ms. Surviving across
  // stop events so users can drag to a spot, play, and come back to it.
  int _seekAnchorMs = 0;
  // In-flight playhead drag (null when not dragging).
  int? _draggingPlayheadMs;

  // Used to convert global drop coordinates to local stack coordinates.
  final GlobalKey _tracksStackKey = GlobalKey();

  // Sequential "Play All" state — cancellable by Enter/P shortcut.
  bool _playingAll = false;
  Completer<void>? _playAllCancel;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Don't swallow keys while a text field has focus.
    final focused = FocusManager.instance.primaryFocus;
    if (focused?.context?.widget is EditableText) return false;
    if (focused?.context?.findAncestorStateOfType<EditableTextState>() !=
        null) {
      return false;
    }
    final key = event.logicalKey;
    final isToggleKey =
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isToggleKey) return false;
    final playback = ref.read(playbackNotifierProvider);
    if (_playingAll || playback.isPlaying) {
      _stopPlayAll();
      return true;
    }
    final clips =
        ref.read(timelineClipsStreamProvider(_streamKey)).valueOrNull ??
        const <db.TimelineClip>[];
    if (clips.isEmpty) return false;
    _playAll(clips);
    return true;
  }

  /// Stop the current play-all run (or single playback) and park the
  /// playhead at the stored seek anchor so the user can resume there.
  void _stopPlayAll() {
    _playAllCancel?.complete();
    _playAllCancel = null;
    if (mounted && _playingAll) setState(() => _playingAll = false);
    ref.read(playbackNotifierProvider.notifier).stop();
  }

  Future<void> _playAll(List<db.TimelineClip> clips) async {
    if (clips.isEmpty || _playingAll) return;
    final ordered = [...clips]
      ..sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
    // Skip clips that finish strictly before the anchor so Play All
    // honours the user's dragged-playhead starting point.
    final anchor = _seekAnchorMs;
    final fromAnchor = ordered.where((c) {
      final endMs = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      return endMs > anchor;
    }).toList();
    if (fromAnchor.isEmpty) return;
    final cancel = Completer<void>();
    setState(() {
      _playingAll = true;
      _playAllCancel = cancel;
    });
    final notifier = ref.read(playbackNotifierProvider.notifier);
    final player = ref.read(audioPlayerProvider);
    int playheadMs = anchor;
    try {
      for (int i = 0; i < fromAnchor.length; i++) {
        if (cancel.isCompleted) break;
        final c = fromAnchor[i];
        // Honour the gap between the previous clip's end and this clip's
        // start — the playhead coasts silently through it, PR-style.
        if (c.startTimeMs > playheadMs) {
          final gapMs = c.startTimeMs - playheadMs;
          final gapStart = DateTime.now();
          final gapFuture = Future.delayed(Duration(milliseconds: gapMs));
          // Animate the playhead through the gap so the user sees motion.
          while (!cancel.isCompleted) {
            final elapsed = DateTime.now().difference(gapStart).inMilliseconds;
            if (elapsed >= gapMs) break;
            if (mounted) {
              setState(() => _seekAnchorMs = playheadMs + elapsed);
            }
            await Future.any([
              Future.delayed(const Duration(milliseconds: 50)),
              cancel.future,
              gapFuture,
            ]);
            if (elapsed + 50 >= gapMs) break;
          }
          if (cancel.isCompleted) break;
          playheadMs = c.startTimeMs;
          if (mounted) setState(() => _seekAnchorMs = playheadMs);
        }
        // Play the clip, seeking inside it if the anchor landed mid-clip.
        final clipOffsetMs = playheadMs > c.startTimeMs
            ? playheadMs - c.startTimeMs
            : 0;
        if (mounted) setState(() => _activeClipId = c.id);
        await notifier.load(c.audioPath, c.label.isEmpty ? 'Clip' : c.label);
        if (clipOffsetMs > 0) {
          // audioplayers may not have the duration yet; a short delay
          // before seeking avoids being ignored by the platform backend.
          await Future.delayed(const Duration(milliseconds: 40));
          await notifier.seek(Duration(milliseconds: clipOffsetMs));
        }
        await Future.any([player.onPlayerComplete.first, cancel.future]);
        final clipDurMs = ((c.durationSec ?? 0) * 1000).round();
        playheadMs = c.startTimeMs + clipDurMs;
        if (mounted) {
          setState(() {
            _activeClipId = null;
            _seekAnchorMs = playheadMs;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _playingAll = false;
          _playAllCancel = null;
          _activeClipId = null;
        });
      }
    }
  }

  /// Jump the playhead anchor to the start of the previous / next clip
  /// (ordered by startTimeMs). Stops any active playback so the change is
  /// immediately visible, and selects the clip for context.
  void _jumpToSibling(List<db.TimelineClip> clips, {required bool next}) {
    if (clips.isEmpty) return;
    final ordered = [...clips]
      ..sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
    db.TimelineClip? target;
    if (next) {
      target = ordered.firstWhere(
        (c) => c.startTimeMs > _seekAnchorMs,
        orElse: () => ordered.last,
      );
    } else {
      target = ordered.lastWhere(
        (c) => c.startTimeMs < _seekAnchorMs,
        orElse: () => ordered.first,
      );
    }
    _stopPlayAll();
    setState(() {
      _seekAnchorMs = target!.startTimeMs;
      _selectedClipId = target.id;
    });
  }

  String get _streamKey => '${widget.projectType}:${widget.projectId}';

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(timelineClipsStreamProvider(_streamKey));
    final playback = ref.watch(playbackNotifierProvider);
    final clips = clipsAsync.valueOrNull ?? const <db.TimelineClip>[];

    int minLane = -1;
    int maxLane = 1;
    for (final c in clips) {
      if (c.laneIndex < minLane) minLane = c.laneIndex;
      if (c.laneIndex > maxLane) maxLane = c.laneIndex;
    }
    final laneCount = maxLane - minLane + 1;

    double totalSec = 0;
    for (final c in clips) {
      final d = c.durationSec ?? 0;
      final end = c.startTimeMs / 1000.0 + d;
      if (end > totalSec) totalSec = end;
    }
    final totalWidth = (totalSec * _pixelsPerSecond) + 200;
    final tracksHeight = laneCount * _laneHeight;

    final baseHeight = _rulerHeight + tracksHeight + 8;
    final tracksAreaHeight = baseHeight + _extraHeight;
    final stackHeight = _rulerHeight + tracksHeight + _extraHeight;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDim,
        border: Border(top: BorderSide(color: Color(0xFF2A2A36))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResizeHandle(baseHeight),
          _buildToolbar(clips, totalSec),
          SizedBox(
            height: tracksAreaHeight,
            child: clips.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).uiDropAVoiceHereOrClickAddToTimelineOnASegment,
                      style: TextStyle(fontSize: 11, color: Colors.white24),
                    ),
                  )
                : Row(
                    children: [
                      _buildLaneLabels(minLane, maxLane),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: DragTarget<TimelineDropPayload>(
                            onAcceptWithDetails: (details) =>
                                _handleDropOnStack(
                                  details.data,
                                  details.offset,
                                  minLane,
                                  clips,
                                ),
                            builder: (context, candidate, rejected) {
                              final hovering = candidate.isNotEmpty;
                              return Container(
                                decoration: BoxDecoration(
                                  color: hovering
                                      ? AppTheme.accentColor.withValues(
                                          alpha: 0.07,
                                        )
                                      : null,
                                ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (d) => _handleRulerTap(
                                    d.localPosition,
                                    stackHeight,
                                  ),
                                  onTap: () =>
                                      setState(() => _selectedClipId = null),
                                  child: SizedBox(
                                    key: _tracksStackKey,
                                    width: totalWidth,
                                    height: stackHeight,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          height: _rulerHeight,
                                          child: CustomPaint(
                                            painter: _TimeRulerPainter(
                                              pixelsPerSecond: _pixelsPerSecond,
                                            ),
                                          ),
                                        ),
                                        for (int i = 0; i <= laneCount; i++)
                                          Positioned(
                                            top: _rulerHeight + i * _laneHeight,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 1,
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                            ),
                                          ),
                                        for (final c in clips)
                                          _positionedClip(c, minLane, playback),
                                        _buildPlayhead(
                                          clips,
                                          playback,
                                          stackHeight,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Thin strip at the top of the timeline whose vertical drag grows the
  /// tracks area. A double-tap resets to the computed baseline.
  Widget _buildResizeHandle(double baseHeight) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) {
          setState(() {
            _extraHeight = (_extraHeight - d.delta.dy).clamp(0.0, 600.0);
          });
        },
        onDoubleTap: () => setState(() => _extraHeight = 0),
        child: Container(
          height: _topHandleHeight,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tapping the time ruler seeks the playhead anchor to that position.
  void _handleRulerTap(Offset localPos, double stackHeight) {
    if (localPos.dy > _rulerHeight) return;
    final ms = (localPos.dx / _pixelsPerSecond * 1000).round().clamp(
      0,
      1 << 30,
    );
    setState(() => _seekAnchorMs = ms);
  }

  /// Insert a new clip using the drop payload at the cursor's lane and time.
  Future<void> _handleDropOnStack(
    TimelineDropPayload payload,
    Offset globalOffset,
    int minLane,
    List<db.TimelineClip> clips,
  ) async {
    final box =
        _tracksStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    final startMs = (local.dx / _pixelsPerSecond * 1000).round().clamp(
      0,
      1 << 30,
    );
    final laneOffset = ((local.dy - _rulerHeight) / _laneHeight).floor();
    final lane = (minLane + laneOffset).clamp(-20, 20);
    await ref
        .read(databaseProvider)
        .insertTimelineClip(
          db.TimelineClipsCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(widget.projectId),
            projectType: Value(widget.projectType),
            laneIndex: Value(lane),
            startTimeMs: Value(startMs),
            durationSec: Value(payload.durationSec),
            audioPath: Value(payload.audioPath),
            sourceType: const Value('generated'),
            sourceLineId: Value(payload.sourceLineId),
            label: Value(payload.label),
          ),
        );
  }

  Widget _positionedClip(
    db.TimelineClip c,
    int minLane,
    PlaybackState playback,
  ) {
    final isDragging = _dragClipId == c.id;
    final effectiveStartMs = isDragging ? _dragStartMs! : c.startTimeMs;
    final effectiveLane = isDragging ? _dragLane! : c.laneIndex;
    return Positioned(
      key: ValueKey(c.id),
      top: _rulerHeight + (effectiveLane - minLane) * _laneHeight + 4,
      left: effectiveStartMs / 1000.0 * _pixelsPerSecond,
      width: ((c.durationSec ?? 1.0) * _pixelsPerSecond).clamp(
        16.0,
        double.infinity,
      ),
      height: _laneHeight - 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedClipId = c.id);
          ref
              .read(playbackNotifierProvider.notifier)
              .load(c.audioPath, c.label.isEmpty ? 'Clip' : c.label);
        },
        onPanStart: (_) {
          setState(() {
            _selectedClipId = c.id;
            _dragClipId = c.id;
            _dragStartMs = c.startTimeMs;
            _dragLane = c.laneIndex;
            _dragOriginLane = c.laneIndex;
            _dragCumulativeDy = 0;
          });
        },
        onPanUpdate: (details) {
          if (_dragClipId != c.id) return;
          // Per-frame dy is often ~2–3px which rounds to 0 against a 52px
          // lane. Accumulate and compute once so vertical drags actually
          // switch lanes instead of being silently truncated.
          _dragCumulativeDy += details.delta.dy;
          final newMs =
              (_dragStartMs! +
                      (details.delta.dx / _pixelsPerSecond * 1000).round())
                  .clamp(0, 1 << 30);
          final origin = _dragOriginLane ?? c.laneIndex;
          final laneShift = (_dragCumulativeDy / _laneHeight).round();
          final newLane = (origin + laneShift).clamp(-20, 20);
          setState(() {
            _dragStartMs = newMs;
            _dragLane = newLane;
          });
        },
        onPanEnd: (_) {
          final id = _dragClipId;
          final ms = _dragStartMs;
          final lane = _dragLane;
          setState(() {
            _dragClipId = null;
            _dragStartMs = null;
            _dragLane = null;
            _dragOriginLane = null;
            _dragCumulativeDy = 0;
          });
          if (id != null && ms != null && lane != null) {
            ref
                .read(databaseProvider)
                .moveTimelineClip(id, laneIndex: lane, startTimeMs: ms);
          }
        },
        child: _ClipTile(
          clip: c,
          isActive: playback.audioPath == c.audioPath,
          isSelected: _selectedClipId == c.id,
          isDragging: isDragging,
        ),
      ),
    );
  }

  Widget _buildToolbar(List<db.TimelineClip> clips, double totalSec) {
    final selected = _selectedClipId == null
        ? null
        : clips.where((c) => c.id == _selectedClipId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).uiTimeline,
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          SizedBox(width: 12),
          Text(
            '${clips.length} clips · ${_fmtSec(totalSec)}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          if (selected != null) ...[
            SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${selected.label.isEmpty ? 'Clip' : selected.label} · '
                '${(selected.startTimeMs / 1000).toStringAsFixed(2)}s · L${selected.laneIndex}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.redAccent,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: AppLocalizations.of(context).uiDeleteClip,
              onPressed: () {
                final id = selected.id;
                setState(() => _selectedClipId = null);
                ref.read(databaseProvider).deleteTimelineClip(id);
              },
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: AppLocalizations.of(context).uiPreviousVoice,
            onPressed: clips.isEmpty
                ? null
                : () => _jumpToSibling(clips, next: false),
          ),
          TextButton.icon(
            icon: Icon(
              _playingAll ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 14,
            ),
            label: Text(
              _playingAll ? 'Stop' : 'Play all',
              style: const TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _playingAll
                  ? Colors.amber
                  : AppTheme.accentColor,
            ),
            onPressed: clips.isEmpty
                ? null
                : (_playingAll ? _stopPlayAll : () => _playAll(clips)),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: AppLocalizations.of(context).uiNextVoice,
            onPressed: clips.isEmpty
                ? null
                : () => _jumpToSibling(clips, next: true),
          ),
          SizedBox(width: 4),
          Tooltip(
            message: AppLocalizations.of(context).uiSpaceEnterPToPlayOrStop,
            child: Icon(
              Icons.keyboard_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.library_music_rounded, size: 14),
            label: Text(
              AppLocalizations.of(context).uiImport,
              style: TextStyle(fontSize: 11),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showImportMenu(clips),
          ),
          SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: () => setState(
              () => _pixelsPerSecond = (_pixelsPerSecond / 1.5).clamp(10, 200),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: () => setState(
              () => _pixelsPerSecond = (_pixelsPerSecond * 1.5).clamp(10, 200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneLabels(int minLane, int maxLane) {
    return SizedBox(
      width: 28,
      child: Column(
        children: [
          SizedBox(height: _rulerHeight),
          for (int lane = minLane; lane <= maxLane; lane++)
            SizedBox(
              height: _laneHeight,
              child: Center(
                child: Text(
                  '$lane',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The playhead has two personalities:
  ///   • During playback it tracks the active clip's position live.
  ///   • Otherwise it parks at [_seekAnchorMs] so the user can scrub to a
  ///     spot, press Play/Stop, and return to the same anchor.
  /// The handle at the top is draggable to seek.
  Widget _buildPlayhead(
    List<db.TimelineClip> clips,
    PlaybackState playback,
    double stackHeight,
  ) {
    int currentMs;
    if (_draggingPlayheadMs != null) {
      currentMs = _draggingPlayheadMs!;
    } else if (_activeClipId != null) {
      final activeClip = clips.where((c) => c.id == _activeClipId).firstOrNull;
      if (activeClip != null &&
          playback.isPlaying &&
          playback.audioPath == activeClip.audioPath) {
        // Actively playing this clip — track the live position.
        currentMs = activeClip.startTimeMs + playback.position.inMilliseconds;
      } else if (activeClip != null) {
        // Player state is transitioning between clips in Play All:
        // onPlayerComplete zeros out position and flips isPlaying before
        // _playAll advances _seekAnchorMs. Pin the playhead to the clip's
        // end so it doesn't visibly snap back to the clip's start for a
        // frame during the hand-off.
        final durMs = ((activeClip.durationSec ?? 0) * 1000).round();
        currentMs = activeClip.startTimeMs + durMs;
      } else {
        currentMs = _seekAnchorMs;
      }
    } else if (playback.isPlaying && playback.audioPath != null) {
      final activeClip = clips
          .where((c) => c.audioPath == playback.audioPath)
          .firstOrNull;
      if (activeClip != null) {
        currentMs = activeClip.startTimeMs + playback.position.inMilliseconds;
      } else {
        currentMs = _seekAnchorMs;
      }
    } else {
      currentMs = _seekAnchorMs;
    }
    final x = currentMs / 1000.0 * _pixelsPerSecond;
    return Positioned(
      top: 0,
      left: x - 6,
      width: 14,
      height: stackHeight,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            setState(() => _draggingPlayheadMs = currentMs);
          },
          onPanUpdate: (d) {
            final delta = (d.delta.dx / _pixelsPerSecond * 1000).round();
            setState(() {
              _draggingPlayheadMs = ((_draggingPlayheadMs ?? currentMs) + delta)
                  .clamp(0, 1 << 30);
            });
          },
          onPanEnd: (_) {
            final finalMs = _draggingPlayheadMs;
            setState(() {
              if (finalMs != null) _seekAnchorMs = finalMs;
              _draggingPlayheadMs = null;
            });
            // If playback is currently active, seek into the active clip.
            final p = ref.read(playbackNotifierProvider);
            if (finalMs != null && p.isPlaying && p.audioPath != null) {
              final active = clips
                  .where((c) => c.audioPath == p.audioPath)
                  .firstOrNull;
              if (active != null) {
                final off = finalMs - active.startTimeMs;
                if (off >= 0 &&
                    off <= ((active.durationSec ?? 0) * 1000).round()) {
                  ref
                      .read(playbackNotifierProvider.notifier)
                      .seek(Duration(milliseconds: off));
                }
              }
            }
          },
          child: Stack(
            children: [
              // Centered 2px vertical line.
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.amber),
              ),
              // Grab handle at the top so it's obvious the line is draggable.
              Positioned(
                left: 0,
                top: 0,
                width: 14,
                height: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtSec(double secs) {
    final m = (secs / 60).floor();
    final s = (secs % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _nextStartMs(List<db.TimelineClip> clips) {
    int end = 0;
    for (final c in clips) {
      final e = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (e > end) end = e;
    }
    return end;
  }

  Future<void> _showImportMenu(List<db.TimelineClip> clips) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceBright,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.library_music_rounded),
              title: Text(
                AppLocalizations.of(context).uiImportFromAudioLibrary,
              ),
              subtitle: Text(
                AppLocalizations.of(context).uiPickAClipCollectedInTheApp,
              ),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: Text(AppLocalizations.of(context).uiImportSFXFromFile),
              subtitle: Text(
                AppLocalizations.of(context).uiPickAnAudioFileFromDisk,
              ),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'library') {
      await _importFromLibrary(clips);
    } else if (choice == 'file') {
      await _importFromFile(clips);
    }
  }

  Future<void> _importFromLibrary(List<db.TimelineClip> clips) async {
    final tracks = ref.read(audioTracksStreamProvider).valueOrNull ?? const [];
    if (tracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiAudioLibraryIsEmpty),
          ),
        );
      }
      return;
    }
    final picked = await showDialog<db.AudioTrack>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surfaceBright,
        child: SizedBox(
          width: 360,
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).uiPickAudio,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final t = tracks[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.audiotrack_rounded,
                        size: 18,
                        color: AppTheme.accentColor,
                      ),
                      title: Text(t.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${t.sourceType} · '
                        '${t.durationSec != null ? "${t.durationSec!.toStringAsFixed(1)}s" : "?"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    // Library tracks may have been catalogued without a duration — fall
    // back to probing the file so the timeline clip gets a real width.
    double? dur = picked.durationSec;
    dur ??= await measureAudioDuration(picked.audioPath);
    await ref
        .read(databaseProvider)
        .insertTimelineClip(
          db.TimelineClipsCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(widget.projectId),
            projectType: Value(widget.projectType),
            laneIndex: const Value(0),
            startTimeMs: Value(_nextStartMs(clips)),
            durationSec: Value(dur),
            audioPath: Value(picked.audioPath),
            sourceType: const Value('imported'),
            label: Value(picked.name),
          ),
        );
  }

  Future<void> _importFromFile(List<db.TimelineClip> clips) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final src = result.files.single.path;
    if (src == null) return;

    final storage = ref.read(storageServiceProvider);
    final slug = widget.projectType == 'phase'
        ? await storage.ensurePhaseProjectSlug(widget.projectId)
        : await storage.ensureDialogProjectSlug(widget.projectId);
    final outDir = await PathService.instance.timelineSfxDir(
      projectType: widget.projectType,
      projectName: slug,
    );
    final ext = p.extension(src);
    final destPath = PathService.dedupeFilename(
      outDir,
      'sfx_${PathService.formatTimestamp()}',
      ext,
    );
    await File(src).copy(destPath);

    final label = p.basenameWithoutExtension(src);
    // Probe the copied file so the imported clip renders at its true
    // width and the Play-All scheduler advances by the real duration.
    final dur = await measureAudioDuration(destPath);
    await ref
        .read(databaseProvider)
        .insertTimelineClip(
          db.TimelineClipsCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(widget.projectId),
            projectType: Value(widget.projectType),
            laneIndex: const Value(1),
            startTimeMs: Value(_nextStartMs(clips)),
            durationSec: Value(dur),
            audioPath: Value(destPath),
            sourceType: const Value('sfx'),
            label: Value(label),
          ),
        );
  }
}

class _ClipTile extends StatelessWidget {
  final db.TimelineClip clip;
  final bool isActive;
  final bool isSelected;
  final bool isDragging;

  const _ClipTile({
    required this.clip,
    required this.isActive,
    required this.isSelected,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (clip.sourceType) {
      case 'imported':
        bg = const Color(0xFF3A5AA3);
        break;
      case 'sfx':
        bg = const Color(0xFF8A6A2C);
        break;
      default:
        bg = AppTheme.accentColor;
    }
    final borderColor = isSelected
        ? Colors.amber
        : isActive
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.15);
    return Opacity(
      opacity: isDragging ? 0.75 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: isActive || isSelected ? bg : bg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : (isActive ? 1.5 : 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          clip.label.isEmpty ? 'Clip' : clip.label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _TimeRulerPainter extends CustomPainter {
  final double pixelsPerSecond;
  _TimeRulerPainter({required this.pixelsPerSecond});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    const textStyle = TextStyle(color: Colors.white38, fontSize: 9);
    int sec = 0;
    while (sec * pixelsPerSecond < size.width) {
      final x = sec * pixelsPerSecond;
      final isMajor = sec % 5 == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 4 : 8),
        Offset(x, size.height),
        isMajor ? majorPaint : tickPaint,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(text: '${sec}s', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, 0));
      }
      sec++;
    }
  }

  @override
  bool shouldRepaint(_TimeRulerPainter old) =>
      old.pixelsPerSecond != pixelsPerSecond;
}
