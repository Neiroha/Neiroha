import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart' as db;
import '../../providers/app_providers.dart';
import '../../providers/playback_provider.dart';
import '../theme/app_theme.dart';

/// Multi-lane editable timeline backed by the `TimelineClips` table.
/// Clips are positioned by `startTimeMs` and `laneIndex`, independent of the
/// source line order. Supports horizontal drag to reposition, vertical drag
/// to change lane, tap to select, and delete of selected clip.
class StoryTrackEditor extends ConsumerStatefulWidget {
  final String projectId;
  final String projectType; // 'dialog' | 'phase'

  const StoryTrackEditor({
    super.key,
    required this.projectId,
    required this.projectType,
  });

  @override
  ConsumerState<StoryTrackEditor> createState() => _StoryTrackEditorState();
}

class _StoryTrackEditorState extends ConsumerState<StoryTrackEditor> {
  double _pixelsPerSecond = 50.0;
  final _scrollController = ScrollController();
  static const double _laneHeight = 52.0;
  static const double _rulerHeight = 18.0;

  String? _selectedClipId;
  // In-flight drag state (null when not dragging).
  String? _dragClipId;
  int? _dragStartMs;
  int? _dragLane;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDim,
        border: Border(top: BorderSide(color: Color(0xFF2A2A36))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbar(clips, totalSec),
          SizedBox(
            height: _rulerHeight + tracksHeight + 8,
            child: clips.isEmpty
                ? const Center(
                    child: Text(
                      'Generate audio to populate the timeline',
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                setState(() => _selectedClipId = null),
                            child: SizedBox(
                              width: totalWidth,
                              height: _rulerHeight + tracksHeight,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: _rulerHeight,
                                    child: CustomPaint(
                                      painter: _TimeRulerPainter(
                                          pixelsPerSecond: _pixelsPerSecond),
                                    ),
                                  ),
                                  for (int i = 0; i <= laneCount; i++)
                                    Positioned(
                                      top: _rulerHeight + i * _laneHeight,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 1,
                                        color: Colors.white
                                            .withValues(alpha: 0.05),
                                      ),
                                    ),
                                  for (final c in clips)
                                    _positionedClip(c, minLane, playback),
                                  if (playback.audioPath != null)
                                    _buildPlayhead(clips, playback),
                                ],
                              ),
                            ),
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

  Widget _positionedClip(
      db.TimelineClip c, int minLane, PlaybackState playback) {
    final isDragging = _dragClipId == c.id;
    final effectiveStartMs = isDragging ? _dragStartMs! : c.startTimeMs;
    final effectiveLane = isDragging ? _dragLane! : c.laneIndex;
    return Positioned(
      key: ValueKey(c.id),
      top: _rulerHeight + (effectiveLane - minLane) * _laneHeight + 4,
      left: effectiveStartMs / 1000.0 * _pixelsPerSecond,
      width: ((c.durationSec ?? 1.0) * _pixelsPerSecond)
          .clamp(16.0, double.infinity),
      height: _laneHeight - 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedClipId = c.id);
          ref.read(playbackNotifierProvider.notifier).load(
                c.audioPath,
                c.label.isEmpty ? 'Clip' : c.label,
              );
        },
        onPanStart: (_) {
          setState(() {
            _selectedClipId = c.id;
            _dragClipId = c.id;
            _dragStartMs = c.startTimeMs;
            _dragLane = c.laneIndex;
          });
        },
        onPanUpdate: (details) {
          if (_dragClipId != c.id) return;
          final newMs = (_dragStartMs! +
                  (details.delta.dx / _pixelsPerSecond * 1000).round())
              .clamp(0, 1 << 30);
          final laneDelta = (details.delta.dy / _laneHeight).round();
          final newLane = _dragLane! + laneDelta;
          setState(() {
            _dragStartMs = newMs;
            if (laneDelta != 0) _dragLane = newLane;
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
          const Text('Timeline',
              style: TextStyle(fontSize: 11, color: Colors.white54)),
          const SizedBox(width: 12),
          Text(
            '${clips.length} clips · ${_fmtSec(totalSec)}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          if (selected != null) ...[
            const SizedBox(width: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Colors.redAccent),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: 'Delete clip',
              onPressed: () {
                final id = selected.id;
                setState(() => _selectedClipId = null);
                ref.read(databaseProvider).deleteTimelineClip(id);
              },
            ),
          ],
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.library_music_rounded, size: 14),
            label: const Text('Import', style: TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showImportMenu(clips),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: () => setState(() =>
                _pixelsPerSecond = (_pixelsPerSecond / 1.5).clamp(10, 200)),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: () => setState(() =>
                _pixelsPerSecond = (_pixelsPerSecond * 1.5).clamp(10, 200)),
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
          const SizedBox(height: _rulerHeight),
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

  Widget _buildPlayhead(List<db.TimelineClip> clips, PlaybackState playback) {
    final activeClip =
        clips.where((c) => c.audioPath == playback.audioPath).firstOrNull;
    if (activeClip == null) return const SizedBox.shrink();
    final posSec = playback.position.inMilliseconds / 1000.0;
    final x =
        (activeClip.startTimeMs / 1000.0 + posSec) * _pixelsPerSecond;
    return Positioned(
      top: 0,
      left: x,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: Colors.amber),
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
              title: const Text('Import from Audio Library'),
              subtitle: const Text('Pick a clip collected in the app'),
              onTap: () => Navigator.pop(ctx, 'library'),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Import SFX from file'),
              subtitle: const Text('Pick an audio file from disk'),
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
    final tracks =
        ref.read(audioTracksStreamProvider).valueOrNull ?? const [];
    if (tracks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio library is empty')),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Pick audio',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
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
                      leading: Icon(Icons.audiotrack_rounded,
                          size: 18,
                          color: AppTheme.accentColor),
                      title: Text(t.name,
                          style: const TextStyle(fontSize: 13)),
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
    await ref.read(databaseProvider).insertTimelineClip(
          db.TimelineClipsCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(widget.projectId),
            projectType: Value(widget.projectType),
            laneIndex: const Value(0),
            startTimeMs: Value(_nextStartMs(clips)),
            durationSec: Value(picked.durationSec),
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

    final dir = await getApplicationSupportDirectory();
    final outDir = Directory(p.join(
        dir.path, 'timeline_sfx', widget.projectType, widget.projectId));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final ext = p.extension(src);
    final destPath = p.join(outDir.path,
        'sfx_${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(src).copy(destPath);

    final label = p.basenameWithoutExtension(src);
    await ref.read(databaseProvider).insertTimelineClip(
          db.TimelineClipsCompanion(
            id: Value(const Uuid().v4()),
            projectId: Value(widget.projectId),
            projectType: Value(widget.projectType),
            laneIndex: const Value(1),
            startTimeMs: Value(_nextStartMs(clips)),
            durationSec: const Value(null),
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
