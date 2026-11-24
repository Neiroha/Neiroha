part of 'timeline.dart';

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
