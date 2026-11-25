part of 'timeline.dart';

// ─────────────── painters ───────────────

class _RulerPainter extends CustomPainter {
  final double pxPerMs;
  final int viewLeftMs;
  final int viewSpanMs;
  final Color fg;

  _RulerPainter({
    required this.pxPerMs,
    required this.viewLeftMs,
    required this.viewSpanMs,
    required this.fg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = fg.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = fg.withValues(alpha: 0.38)
      ..strokeWidth = 1;
    final textStyle = TextStyle(color: fg.withValues(alpha: 0.38), fontSize: 9);

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
      old.viewSpanMs != viewSpanMs ||
      old.fg != fg;
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
      old.totalMs != totalMs ||
      old.color != color;
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
