part of 'timeline.dart';

/// Track bodies: cue and clip lanes, playhead and range scrubber.
extension _TimelineLanes on _VideoDubTimelineState {
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
                fg: context.fg,
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
                    ? context.fg.withValues(alpha: 0.015)
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
                  _update(() {
                    _dragCueId = cue.id;
                    _dragCueDxPx = 0.0;
                  });
                },
          onHorizontalDragUpdate: widget.onMoveCue == null
              ? null
              : (d) {
                  if (_dragCueId != cue.id) return;
                  _update(() => _dragCueDxPx += d.delta.dx);
                },
          onHorizontalDragEnd: widget.onMoveCue == null
              ? null
              : (_) {
                  if (_dragCueId != cue.id) return;
                  final dxMs = (_dragCueDxPx / pxPerMs).round();
                  _update(() {
                    _dragCueId = null;
                    _dragCueDxPx = 0.0;
                  });
                  if (dxMs != 0) {
                    widget.onMoveCue!(cue, cue.startMs + dxMs);
                  }
                },
          onHorizontalDragCancel: () {
            if (_dragCueId != cue.id) return;
            _update(() {
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
                color: context.fg.withValues(alpha: 0.12),
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
        icon = Icons.movie_rounded;
        break;
      case 'image':
        bg = const Color(0xFF2C8F7A);
        icon = Icons.image_rounded;
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
        color: context.colors.raised,
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
            _update(() {
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
