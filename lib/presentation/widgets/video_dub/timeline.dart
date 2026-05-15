import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Multi-track timeline for Video Dub. Shows:
///   • V1 — imported video (from TimelineClips)
///   • A1 — the video's linked original audio (from TimelineClips)
///   • A2 — TTS cues (from SubtitleCues)
///   • A3 — imported audio (from TimelineClips)
///
/// Navigation is range-based (Premiere-style): two handles at the bottom
/// define the visible window [leftMs, rightMs]. Bringing them together
/// zooms in; spreading them apart zooms out. The conventional zoom buttons
/// are gone.
class VideoDubTimeline extends StatefulWidget {
  final List<db.SubtitleCue> cues;
  final List<db.TimelineClip> clips;
  final Map<String, db.VoiceAsset> assetMap;
  final Duration position;
  final Duration duration;
  final String? selectedCueId;
  final String? selectedClipId;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<db.SubtitleCue> onTapCue;
  final ValueChanged<db.TimelineClip> onTapClip;
  final ValueChanged<db.TimelineClip> onDeleteClip;
  final void Function(DubImportKind) onImport;

  /// Drag commit for an A2 cue block — `newStartMs` is the proposed
  /// new start; the caller is responsible for clamping and persisting.
  final void Function(db.SubtitleCue cue, int newStartMs)? onMoveCue;

  /// Whether V1 already has a clip — disables the "Import video" button
  /// so the user can't accidentally stack a second source on the dubber.
  final bool v1Occupied;

  /// A1 mute state and toggle. The mute is owned by the parent (it also
  /// drives playback), this is just the UI affordance in the track header.
  final bool a1Muted;
  final VoidCallback? onToggleA1Mute;
  final List<double>? waveformPeaks;
  final bool ffmpegAvailable;
  final VoidCallback onConfigureFfmpeg;

  const VideoDubTimeline({
    super.key,
    required this.cues,
    required this.clips,
    required this.assetMap,
    required this.position,
    required this.duration,
    required this.selectedCueId,
    required this.selectedClipId,
    required this.onSeek,
    required this.onTapCue,
    required this.onTapClip,
    required this.onDeleteClip,
    required this.onImport,
    required this.waveformPeaks,
    required this.ffmpegAvailable,
    required this.onConfigureFfmpeg,
    this.onMoveCue,
    this.v1Occupied = false,
    this.a1Muted = false,
    this.onToggleA1Mute,
  });

  @override
  State<VideoDubTimeline> createState() => _VideoDubTimelineState();
}

class _VideoDubTimelineState extends State<VideoDubTimeline> {
  static const double _trackHeight = 44.0;
  static const double _rulerHeight = 18.0;
  static const double _scrubberHeight = 38.0;
  static const double _headerWidth = 82.0;
  final _verticalScrollController = ScrollController();

  // Visible window in ms — the range scrubber drives these.
  int _viewLeftMs = 0;
  int? _viewRightMs; // null = fit to content on first build

  // Cue drag state — id of the cue currently being dragged on A2, plus
  // the running pixel delta so we can render the block at its in-flight
  // position before committing on drag-end.
  String? _dragCueId;
  double _dragCueDxPx = 0.0;

  int get _contentTotalMs {
    final durMs = widget.duration.inMilliseconds;
    var maxEnd = durMs;
    for (final c in widget.cues) {
      if (c.endMs > maxEnd) maxEnd = c.endMs;
    }
    for (final c in widget.clips) {
      final end = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (end > maxEnd) maxEnd = end;
    }
    return maxEnd > 0 ? maxEnd : 60000;
  }

  int get _viewSpanMs {
    final right = _viewRightMs ?? _contentTotalMs;
    final span = right - _viewLeftMs;
    return span > 500 ? span : 500; // clamp so math doesn't explode at 0
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _contentTotalMs;
    _viewRightMs ??= total;

    // If content grew past the scrubber's right edge, nudge it out.
    if (_viewRightMs! < total &&
        _viewRightMs! == total /* no-op — keep for clarity */ ) {
      // keep
    }
    _viewRightMs = _viewRightMs!.clamp(0, total);
    _viewLeftMs = _viewLeftMs.clamp(0, _viewRightMs! - 500).clamp(0, total);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWidth = (constraints.maxWidth - _headerWidth).clamp(
          120.0,
          constraints.maxWidth,
        );
        final pxPerMs = bodyWidth / _viewSpanMs;

        final tracks = _buildTrackList();
        final trackContentHeight = _rulerHeight + tracks.length * _trackHeight;

        return Container(
          color: AppTheme.surfaceDim,
          child: Column(
            children: [
              _buildToolbar(),
              const Divider(height: 1),
              if (!widget.ffmpegAvailable) _buildFfmpegBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final viewportHeight = viewport.maxHeight.isFinite
                        ? viewport.maxHeight
                        : trackContentHeight;
                    final contentHeight = trackContentHeight > viewportHeight
                        ? trackContentHeight
                        : viewportHeight;
                    return Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: trackContentHeight > viewportHeight,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        child: SizedBox(
                          height: contentHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: _headerWidth,
                                child: _buildTrackHeaders(tracks),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: ExcludeSemantics(
                                  child: _buildTrackBody(tracks, pxPerMs),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildRangeScrubber(total),
            ],
          ),
        );
      },
    );
  }

  // ─────────────── toolbar ───────────────

  Widget _buildToolbar() {
    final v1Tooltip = widget.v1Occupied
        ? 'Only one video allowed — delete the V1 clip to import another'
        : 'Import a video onto V1 (its audio appears on A1)';
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context).uiDubTimeline,
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${widget.cues.length} cues · ${widget.clips.length} clips · ${_fmtMs(_contentTotalMs)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    SizedBox(width: 24),
                    Tooltip(
                      message: v1Tooltip,
                      child: OutlinedButton.icon(
                        onPressed: widget.v1Occupied
                            ? null
                            : () => widget.onImport(DubImportKind.video),
                        icon: const Icon(Icons.movie_outlined, size: 16),
                        label: Text(AppLocalizations.of(context).uiImportVideo),
                      ),
                    ),
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => widget.onImport(DubImportKind.audio),
                      icon: const Icon(Icons.audiotrack_rounded, size: 16),
                      label: Text(AppLocalizations.of(context).uiImportAudio),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────── FFmpeg banner ───────────────

  Widget _buildFfmpegBanner() {
    return Container(
      color: Colors.amber.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              ).uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped,
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: widget.onConfigureFfmpeg,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppLocalizations.of(context).navSettings,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── track layout ───────────────

  List<_TrackRow> _buildTrackList() {
    // Simplified 1V3A: V1 video + three audio rails.
    return const [
      _TrackRow.video(kind: _TrackKind.v1, label: 'V1 · Video'),
      _TrackRow.videoAudio(label: 'A1 · Video'),
      _TrackRow.tts(label: 'A2 · TTS'),
      _TrackRow.audio(kind: _TrackKind.a3, label: 'A3 · Audio'),
    ];
  }

  Widget _buildTrackHeaders(List<_TrackRow> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _rulerHeight),
        for (final t in tracks)
          SizedBox(
            height: _trackHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.kind == _TrackKind.a1 && widget.a1Muted
                            ? Colors.white.withValues(alpha: 0.35)
                            : t.accent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.kind == _TrackKind.a1 && widget.onToggleA1Mute != null)
                    Tooltip(
                      message: widget.a1Muted
                          ? 'A1 muted (original video audio off)'
                          : 'Mute A1 (silence original video audio)',
                      child: InkWell(
                        onTap: widget.onToggleA1Mute,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            widget.a1Muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 14,
                            color: widget.a1Muted
                                ? Colors.white.withValues(alpha: 0.35)
                                : t.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrackBody(List<_TrackRow> tracks, double pxPerMs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _handleBodyTap(d.localPosition, pxPerMs),
      child: Stack(
        children: [
          // Ruler at the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _rulerHeight,
            child: CustomPaint(
              painter: _RulerPainter(
                pxPerMs: pxPerMs,
                viewLeftMs: _viewLeftMs,
                viewSpanMs: _viewSpanMs,
              ),
            ),
          ),
          // Lane backgrounds + clips.
          for (var i = 0; i < tracks.length; i++) ...[
            Positioned(
              top: _rulerHeight + i * _trackHeight,
              left: 0,
              right: 0,
              height: _trackHeight,
              child: Container(
                color: i.isOdd
                    ? Colors.white.withValues(alpha: 0.015)
                    : Colors.transparent,
              ),
            ),
            _buildTrackContent(tracks[i], i, pxPerMs),
          ],
          // Playhead overlay.
          _buildPlayhead(tracks, pxPerMs),
        ],
      ),
    );
  }

  /// Body tap on the ruler seeks, elsewhere it clears selection.
  void _handleBodyTap(Offset local, double pxPerMs) {
    if (local.dy <= _rulerHeight) {
      final ms = (_viewLeftMs + local.dx / pxPerMs).round().clamp(
        0,
        _contentTotalMs,
      );
      widget.onSeek(Duration(milliseconds: ms));
    }
  }

  Widget _buildTrackContent(_TrackRow row, int index, double pxPerMs) {
    final top = _rulerHeight + index * _trackHeight;
    switch (row.kind) {
      case _TrackKind.tts:
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: _trackHeight,
          child: _buildCueLane(pxPerMs),
        );
      case _TrackKind.v1:
      case _TrackKind.a1:
      case _TrackKind.a3:
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          height: _trackHeight,
          child: _buildClipLane(row.kind, pxPerMs),
        );
    }
  }

  Widget _buildCueLane(double pxPerMs) {
    return Stack(
      children: [for (final cue in widget.cues) _buildCueBlock(cue, pxPerMs)],
    );
  }

  Widget _buildCueBlock(db.SubtitleCue cue, double pxPerMs) {
    final isDragging = _dragCueId == cue.id;
    final dx = isDragging ? _dragCueDxPx : 0.0;
    final left = (cue.startMs - _viewLeftMs) * pxPerMs + dx;
    final width = ((cue.endMs - cue.startMs) * pxPerMs).clamp(8.0, 4000.0);
    // Off-screen clips clipped by Positioned's parent bounds; no pre-filter.
    final isSelected = widget.selectedCueId == cue.id;
    final hasAudio = cue.audioPath != null;
    final hasError = cue.error != null;
    final voiceName = cue.voiceAssetId == null
        ? null
        : widget.assetMap[cue.voiceAssetId]?.name;

    Color bg;
    if (hasError) {
      bg = Colors.redAccent.withValues(alpha: 0.55);
    } else if (hasAudio) {
      bg = AppTheme.accentColor;
    } else {
      bg = const Color(0xFF4A4A55);
    }

    return Positioned(
      top: 4,
      left: left,
      width: width,
      height: _trackHeight - 8,
      child: MouseRegion(
        cursor: widget.onMoveCue == null
            ? MouseCursor.defer
            : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTapCue(cue),
          onHorizontalDragStart: widget.onMoveCue == null
              ? null
              : (_) {
                  setState(() {
                    _dragCueId = cue.id;
                    _dragCueDxPx = 0.0;
                  });
                },
          onHorizontalDragUpdate: widget.onMoveCue == null
              ? null
              : (d) {
                  if (_dragCueId != cue.id) return;
                  setState(() => _dragCueDxPx += d.delta.dx);
                },
          onHorizontalDragEnd: widget.onMoveCue == null
              ? null
              : (_) {
                  if (_dragCueId != cue.id) return;
                  final dxMs = (_dragCueDxPx / pxPerMs).round();
                  setState(() {
                    _dragCueId = null;
                    _dragCueDxPx = 0.0;
                  });
                  if (dxMs != 0) {
                    widget.onMoveCue!(cue, cue.startMs + dxMs);
                  }
                },
          onHorizontalDragCancel: () {
            if (_dragCueId != cue.id) return;
            setState(() {
              _dragCueId = null;
              _dragCueDxPx = 0.0;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? bg : bg.withValues(alpha: 0.7),
              border: Border.all(
                color: isSelected
                    ? Colors.amber
                    : Colors.white.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cue.cueText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (voiceName != null)
                  Text(
                    voiceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClipLane(_TrackKind kind, double pxPerMs) {
    final lane = switch (kind) {
      _TrackKind.v1 => DubLanes.v1,
      _TrackKind.a1 => DubLanes.a1,
      _TrackKind.a3 => DubLanes.a3,
      _TrackKind.tts => null, // rendered via _buildCueLane
    };
    if (lane == null) return const SizedBox.shrink();
    final clips = widget.clips.where((c) => c.laneIndex == lane).toList();
    return Stack(
      children: [
        // Waveform rendered as the A1 lane's background so the user sees
        // the audio envelope directly on the track it belongs to.
        if (kind == _TrackKind.a1 &&
            widget.waveformPeaks != null &&
            widget.waveformPeaks!.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _WaveformPainter(
                peaks: widget.waveformPeaks!,
                viewLeftMs: _viewLeftMs,
                viewSpanMs: _viewSpanMs,
                totalMs: widget.duration.inMilliseconds > 0
                    ? widget.duration.inMilliseconds
                    : _contentTotalMs,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        for (final c in clips) _buildClipBlock(c, kind, pxPerMs),
      ],
    );
  }

  Widget _buildClipBlock(
    db.TimelineClip clip,
    _TrackKind kind,
    double pxPerMs,
  ) {
    final durMs = ((clip.durationSec ?? 1) * 1000).round();
    final left = (clip.startTimeMs - _viewLeftMs) * pxPerMs;
    final width = (durMs * pxPerMs).clamp(8.0, 20000.0);
    final isSelected = widget.selectedClipId == clip.id;

    final isMissing = clip.missing;
    Color bg;
    IconData icon;
    switch (clip.sourceType) {
      case 'video':
        bg = const Color(0xFF3A5AA3);
        icon = Icons.movie_outlined;
        break;
      case 'image':
        bg = const Color(0xFF2C8F7A);
        icon = Icons.image_outlined;
        break;
      case 'video-audio':
        bg = const Color(0xFF5C7AB0);
        icon = Icons.graphic_eq_rounded;
        break;
      default:
        // imported audio on A3 (and any legacy A2 rows)
        bg = const Color(0xFF8A6A2C);
        icon = Icons.audiotrack_rounded;
    }
    if (isMissing) {
      bg = Colors.redAccent.withValues(alpha: 0.55);
    }

    return Positioned(
      top: 4,
      left: left,
      width: width,
      height: _trackHeight - 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTapClip(clip),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? bg : bg.withValues(alpha: 0.7),
            border: Border.all(
              color: isSelected
                  ? Colors.amber
                  : Colors.white.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: Colors.white),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  clip.label.isEmpty ? kind.name : clip.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                GestureDetector(
                  onTap: () => widget.onDeleteClip(clip),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayhead(List<_TrackRow> tracks, double pxPerMs) {
    final ms = widget.position.inMilliseconds;
    if (ms < _viewLeftMs || ms > (_viewRightMs ?? _contentTotalMs)) {
      return const SizedBox.shrink();
    }
    final x = (ms - _viewLeftMs) * pxPerMs;
    final bodyHeight = _rulerHeight + tracks.length * _trackHeight;
    return Positioned(
      left: x - 1,
      top: 0,
      width: 2,
      height: bodyHeight,
      child: Container(color: Colors.amber),
    );
  }

  // ─────────────── range scrubber ───────────────

  Widget _buildRangeScrubber(int totalMs) {
    return ExcludeSemantics(
      child: Container(
        height: _scrubberHeight,
        color: AppTheme.surfaceBright,
        padding: const EdgeInsets.only(
          left: _headerWidth,
          right: 8,
          top: 6,
          bottom: 6,
        ),
        child: _RangeScrubber(
          totalMs: totalMs,
          leftMs: _viewLeftMs,
          rightMs: _viewRightMs ?? totalMs,
          playheadMs: widget.position.inMilliseconds,
          clips: widget.clips,
          cues: widget.cues,
          onRangeChanged: (l, r) {
            setState(() {
              _viewLeftMs = l;
              _viewRightMs = r;
            });
          },
          onScrub: (ms) => widget.onSeek(Duration(milliseconds: ms)),
        ),
      ),
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

// ─────────────── internal track row ───────────────

enum _TrackKind { v1, a1, tts, a3 }

class _TrackRow {
  final _TrackKind kind;
  final String label;
  final Color accent;

  const factory _TrackRow.video({
    required _TrackKind kind,
    required String label,
  }) = _TrackRow._video;

  const factory _TrackRow.audio({
    required _TrackKind kind,
    required String label,
  }) = _TrackRow._audio;

  const factory _TrackRow.tts({required String label}) = _TrackRow._ttsRow;

  const factory _TrackRow.videoAudio({required String label}) =
      _TrackRow._videoAudioRow;

  const _TrackRow._video({required this.kind, required this.label})
    : accent = const Color(0xFF8AA4E0);

  const _TrackRow._audio({required this.kind, required this.label})
    : accent = const Color(0xFFE0B97A);

  const _TrackRow._ttsRow({required this.label})
    : kind = _TrackKind.tts,
      accent = const Color(0xFF7EC8A8);

  const _TrackRow._videoAudioRow({required this.label})
    : kind = _TrackKind.a1,
      accent = const Color(0xFFE0B97A);
}

// ─────────────── range scrubber widget ───────────────

class _RangeScrubber extends StatefulWidget {
  final int totalMs;
  final int leftMs;
  final int rightMs;
  final int playheadMs;
  final List<db.TimelineClip> clips;
  final List<db.SubtitleCue> cues;
  final void Function(int leftMs, int rightMs) onRangeChanged;
  final ValueChanged<int> onScrub;

  const _RangeScrubber({
    required this.totalMs,
    required this.leftMs,
    required this.rightMs,
    required this.playheadMs,
    required this.clips,
    required this.cues,
    required this.onRangeChanged,
    required this.onScrub,
  });

  @override
  State<_RangeScrubber> createState() => _RangeScrubberState();
}

class _RangeScrubberState extends State<_RangeScrubber> {
  static const double _handleWidth = 14.0;
  static const int _minSpanMs = 500;

  int? _dragLeftMs;
  int? _dragRightMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0 || widget.totalMs <= 0) {
          return const SizedBox.shrink();
        }

        double msToPx(int ms) =>
            (ms.clamp(0, widget.totalMs) / widget.totalMs) * width;
        int pxToMs(double px) =>
            (px.clamp(0, width) / width * widget.totalMs).round();

        final leftMs = _dragLeftMs ?? widget.leftMs;
        final rightMs = _dragRightMs ?? widget.rightMs;
        final leftX = msToPx(leftMs);
        final rightX = msToPx(rightMs);
        final playX = msToPx(widget.playheadMs);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onScrub(pxToMs(d.localPosition.dx)),
          child: Stack(
            children: [
              // Background strip.
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Miniaturised clip blocks (top half) + cue blocks (bottom half).
              Positioned.fill(
                child: CustomPaint(
                  painter: _MiniOverviewPainter(
                    totalMs: widget.totalMs,
                    clips: widget.clips,
                    cues: widget.cues,
                  ),
                ),
              ),
              // Highlighted visible range.
              Positioned(
                left: leftX,
                top: 3,
                width: (rightX - leftX).clamp(0.0, width),
                bottom: 3,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _beginDrag(),
                    onHorizontalDragUpdate: (d) =>
                        _dragWholeRange(d.delta, width),
                    onHorizontalDragEnd: (_) => _commit(),
                    onHorizontalDragCancel: _cancelDrag,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.75),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Playhead dot.
              Positioned(
                left: playX - 1,
                top: 2,
                width: 2,
                bottom: 2,
                child: Container(color: Colors.amber.withValues(alpha: 0.8)),
              ),
              // Left handle.
              _buildHandle(
                x: leftX,
                onUpdate: (delta) {
                  _beginDrag();
                  final next =
                      ((_dragLeftMs ?? widget.leftMs) +
                              (delta.dx / width * widget.totalMs).round())
                          .clamp(
                            0,
                            (_dragRightMs ?? widget.rightMs) - _minSpanMs,
                          )
                          .toInt();
                  setState(() => _dragLeftMs = next);
                },
                onEnd: _commit,
              ),
              // Right handle.
              _buildHandle(
                x: rightX,
                onUpdate: (delta) {
                  _beginDrag();
                  final next =
                      ((_dragRightMs ?? widget.rightMs) +
                              (delta.dx / width * widget.totalMs).round())
                          .clamp(
                            (_dragLeftMs ?? widget.leftMs) + _minSpanMs,
                            widget.totalMs,
                          )
                          .toInt();
                  setState(() => _dragRightMs = next);
                },
                onEnd: _commit,
              ),
            ],
          ),
        );
      },
    );
  }

  void _beginDrag() {
    if (_dragLeftMs != null && _dragRightMs != null) return;
    setState(() {
      _dragLeftMs = widget.leftMs;
      _dragRightMs = widget.rightMs;
    });
  }

  void _dragWholeRange(Offset delta, double width) {
    if (width <= 0) return;
    _beginDrag();
    final currentLeft = _dragLeftMs ?? widget.leftMs;
    final currentRight = _dragRightMs ?? widget.rightMs;
    final span = currentRight - currentLeft;
    final deltaMs = (delta.dx / width * widget.totalMs).round();
    final nextLeft = (currentLeft + deltaMs)
        .clamp(0, widget.totalMs - span)
        .toInt();
    setState(() {
      _dragLeftMs = nextLeft;
      _dragRightMs = nextLeft + span;
    });
  }

  void _commit() {
    final l = _dragLeftMs ?? widget.leftMs;
    final r = _dragRightMs ?? widget.rightMs;
    setState(() {
      _dragLeftMs = null;
      _dragRightMs = null;
    });
    widget.onRangeChanged(l, r);
  }

  void _cancelDrag() {
    setState(() {
      _dragLeftMs = null;
      _dragRightMs = null;
    });
  }

  Widget _buildHandle({
    required double x,
    required ValueChanged<Offset> onUpdate,
    required VoidCallback onEnd,
  }) {
    return Positioned(
      left: x - _handleWidth / 2,
      top: 0,
      width: _handleWidth,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _beginDrag(),
          onHorizontalDragUpdate: (d) => onUpdate(d.delta),
          onHorizontalDragEnd: (_) => onEnd(),
          onHorizontalDragCancel: _cancelDrag,
          child: Center(
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────── painters ───────────────

class _RulerPainter extends CustomPainter {
  final double pxPerMs;
  final int viewLeftMs;
  final int viewSpanMs;

  _RulerPainter({
    required this.pxPerMs,
    required this.viewLeftMs,
    required this.viewSpanMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    const textStyle = TextStyle(color: Colors.white38, fontSize: 9);

    // Choose a tick interval in seconds that gives ~50..120 px spacing.
    final secondsVisible = viewSpanMs / 1000;
    final targetTicks = (size.width / 80).clamp(4, 24);
    final rawInterval = secondsVisible / targetTicks;
    final interval = _niceInterval(rawInterval.toDouble());

    final startSec = (viewLeftMs / 1000.0).ceilToDouble() - 1;
    for (
      var sec = startSec;
      sec < startSec + secondsVisible + interval;
      sec += interval
    ) {
      final ms = (sec * 1000).round();
      final x = (ms - viewLeftMs) * pxPerMs;
      if (x < -40 || x > size.width + 40) continue;
      final isMajor = (sec % (interval * 5)) == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 4 : 10),
        Offset(x, size.height),
        isMajor ? majorPaint : tickPaint,
      );
      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(text: _fmtSec(sec), style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, 2));
      }
    }
  }

  static double _niceInterval(double secs) {
    // Pick from 0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60...
    const steps = <double>[
      0.1,
      0.25,
      0.5,
      1,
      2,
      5,
      10,
      15,
      30,
      60,
      120,
      300,
      600,
    ];
    for (final s in steps) {
      if (s >= secs) return s;
    }
    return 600;
  }

  static String _fmtSec(double sec) {
    if (sec >= 60) {
      final m = (sec ~/ 60);
      final s = (sec % 60).round();
      return '${m}m${s.toString().padLeft(2, '0')}';
    }
    if (sec == sec.roundToDouble()) return '${sec.toInt()}s';
    return '${sec.toStringAsFixed(1)}s';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.pxPerMs != pxPerMs ||
      old.viewLeftMs != viewLeftMs ||
      old.viewSpanMs != viewSpanMs;
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final int viewLeftMs;
  final int viewSpanMs;
  final int totalMs;
  final Color color;

  _WaveformPainter({
    required this.peaks,
    required this.viewLeftMs,
    required this.viewSpanMs,
    required this.totalMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || totalMs <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final midY = size.height / 2;
    final pxCount = size.width.ceil();
    for (var px = 0; px < pxCount; px++) {
      // Map pixel → ms → peak index.
      final ms = viewLeftMs + (px / pxCount * viewSpanMs);
      if (ms < 0 || ms > totalMs) continue;
      final frac = ms / totalMs;
      final idx = (frac * (peaks.length - 1)).round().clamp(
        0,
        peaks.length - 1,
      );
      final amp = peaks[idx] * (size.height * 0.45);
      canvas.drawLine(
        Offset(px.toDouble(), midY - amp),
        Offset(px.toDouble(), midY + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.peaks != peaks ||
      old.viewLeftMs != viewLeftMs ||
      old.viewSpanMs != viewSpanMs ||
      old.totalMs != totalMs;
}

class _MiniOverviewPainter extends CustomPainter {
  final int totalMs;
  final List<db.TimelineClip> clips;
  final List<db.SubtitleCue> cues;

  _MiniOverviewPainter({
    required this.totalMs,
    required this.clips,
    required this.cues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalMs <= 0) return;
    final halfH = size.height / 2;

    final clipPaint = Paint()
      ..color = const Color(0xFF3A5AA3).withValues(alpha: 0.5);
    final cuePaint = Paint()
      ..color = AppTheme.accentColor.withValues(alpha: 0.5);

    // Upper lane: video/image clips + audio clips bundled.
    for (final c in clips) {
      final durMs = ((c.durationSec ?? 0) * 1000).round();
      final l = (c.startTimeMs / totalMs) * size.width;
      final w = (durMs / totalMs) * size.width;
      canvas.drawRect(
        Rect.fromLTWH(l, 4, w.clamp(1.0, size.width), halfH - 6),
        clipPaint,
      );
    }
    // Lower lane: cues (TTS).
    for (final c in cues) {
      final l = (c.startMs / totalMs) * size.width;
      final w = ((c.endMs - c.startMs) / totalMs) * size.width;
      canvas.drawRect(
        Rect.fromLTWH(l, halfH + 2, w.clamp(1.0, size.width), halfH - 6),
        cuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniOverviewPainter old) =>
      old.totalMs != totalMs || old.clips != clips || old.cues != cues;
}
