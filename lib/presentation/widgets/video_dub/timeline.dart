import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'timeline_lanes.dart';
part 'timeline_painters.dart';
part 'timeline_scrubber.dart';

const double _trackHeight = 44.0;
const double _rulerHeight = 18.0;
const double _scrubberHeight = 38.0;
const double _headerWidth = 82.0;

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
  final bool ffmpegSupported;
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
    required this.ffmpegSupported,
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

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

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
          color: context.colors.panel,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fg.withValues(alpha: 0.54),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${widget.cues.length} cues · ${widget.clips.length} clips · ${_fmtMs(_contentTotalMs)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fg.withValues(alpha: 0.38),
                      ),
                    ),
                    SizedBox(width: 24),
                    Tooltip(
                      message: v1Tooltip,
                      child: OutlinedButton.icon(
                        onPressed: widget.v1Occupied
                            ? null
                            : () => widget.onImport(DubImportKind.video),
                        icon: const Icon(Icons.movie_rounded, size: 16),
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
              widget.ffmpegSupported
                  ? AppLocalizations.of(
                      context,
                    ).uiFFmpegNotDetectedWaveformsAndMediaProbingAreSkipped
                  : AppLocalizations.of(
                      context,
                    ).uiFFmpegUnavailableWaveformsAndLocalExportsAreDisabled,
              style: TextStyle(
                fontSize: 11,
                color: context.fg.withValues(alpha: 0.70),
              ),
            ),
          ),
          if (widget.ffmpegSupported)
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
                            ? context.fg.withValues(alpha: 0.35)
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
                                ? context.fg.withValues(alpha: 0.35)
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
}
