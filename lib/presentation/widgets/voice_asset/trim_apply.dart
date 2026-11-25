part of 'trim_dialog.dart';

class _TrimWaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double totalSec;
  final double startSec;
  final double endSec;
  final double? playheadSec;
  final Color accent;
  final Color fg;

  _TrimWaveformPainter({
    required this.peaks,
    required this.totalSec,
    required this.startSec,
    required this.endSec,
    required this.playheadSec,
    required this.accent,
    required this.fg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSec <= 0) return;

    final midY = size.height / 2;
    final dim = Paint()..color = fg.withValues(alpha: 0.18);
    final hot = Paint()..color = accent;

    final pxCount = size.width.ceil();
    for (var px = 0; px < pxCount; px++) {
      final secs = (px / pxCount) * totalSec;
      final inRange = secs >= startSec && secs <= endSec;
      final paint = inRange ? hot : dim;
      double amp = 0;
      if (peaks.isNotEmpty) {
        final idx = ((secs / totalSec) * (peaks.length - 1)).round().clamp(
          0,
          peaks.length - 1,
        );
        amp = peaks[idx];
      } else {
        amp = 0.05;
      }
      final h = amp * size.height * 0.45;
      canvas.drawLine(
        Offset(px.toDouble(), midY - h),
        Offset(px.toDouble(), midY + h),
        paint,
      );
    }

    // Translucent overlay over the kept region so it's obvious even with no
    // peaks (silent file).
    final keepPaint = Paint()..color = accent.withValues(alpha: 0.10);
    final keepLeft = (startSec / totalSec) * size.width;
    final keepRight = (endSec / totalSec) * size.width;
    canvas.drawRect(
      Rect.fromLTRB(keepLeft, 0, keepRight, size.height),
      keepPaint,
    );

    // Range edges.
    final edge = Paint()
      ..color = accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(keepLeft, 0), Offset(keepLeft, size.height), edge);
    canvas.drawLine(Offset(keepRight, 0), Offset(keepRight, size.height), edge);

    // Playhead.
    if (playheadSec != null) {
      final px = (playheadSec! / totalSec) * size.width;
      final ph = Paint()
        ..color = fg
        ..strokeWidth = 1;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), ph);
    }
  }

  @override
  bool shouldRepaint(_TrimWaveformPainter old) =>
      old.peaks != peaks ||
      old.startSec != startSec ||
      old.endSec != endSec ||
      old.playheadSec != playheadSec ||
      old.fg != fg ||
      old.totalSec != totalSec;
}

/// Caller-side helper: call the dialog, run ffmpeg + DB update on the
/// returned [TrimResult]. Centralised so both VoiceAsset inspector and any
/// future callers go through the same code path.
Future<bool> applyTrim({
  required BuildContext context,
  required WidgetRef ref,
  required String audioPath,
  required double currentDurationSec,
  required Future<void> Function({
    required String trimmedPath,
    required double newDurationSec,
    required bool replaceOriginal,
  })
  onSaved,
}) async {
  final result = await showDialog<TrimResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TrimDialog(
      audioPath: audioPath,
      totalSec: currentDurationSec,
      trackName: p.basenameWithoutExtension(audioPath),
    ),
  );
  if (result == null) return false;

  final capabilities = ref.read(platformCapabilitiesProvider);
  if (!capabilities.supportsFfmpegCli) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).uiFFmpegUnavailableOnPlatform(capabilities.platformLabel),
          ),
        ),
      );
    }
    return false;
  }

  final svc = ref.read(ffmpegServiceProvider);
  if (!await svc.isAvailable()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiFFmpegRequiredForTrimming,
          ),
        ),
      );
    }
    return false;
  }

  // Always cut to a sibling temp first; only swap onto the final path after
  // ffmpeg succeeds so we never half-overwrite the source on failure.
  final ext = p.extension(audioPath);
  final dir = p.dirname(audioPath);
  final base = p.basenameWithoutExtension(audioPath);
  final tempPath = p.join(
    dir,
    '$base.trim_${DateTime.now().microsecondsSinceEpoch}$ext',
  );

  final ok = await svc.trimAudio(
    inputPath: audioPath,
    outputPath: tempPath,
    startSec: result.startSec,
    endSec: result.endSec,
  );
  if (!ok) {
    try {
      await File(tempPath).delete();
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiFFmpegTrimFailed),
        ),
      );
    }
    return false;
  }

  String finalPath;
  if (result.replaceOriginal) {
    try {
      await File(audioPath).delete();
    } catch (_) {}
    await File(tempPath).rename(audioPath);
    finalPath = audioPath;
  } else {
    finalPath = p.join(dir, '${base}_trim$ext');
    // If a sibling already exists, keep bumping a counter.
    var i = 2;
    while (await File(finalPath).exists()) {
      finalPath = p.join(dir, '${base}_trim$i$ext');
      i++;
    }
    await File(tempPath).rename(finalPath);
  }

  await onSaved(
    trimmedPath: finalPath,
    newDurationSec: result.durationSec,
    replaceOriginal: result.replaceOriginal,
  );
  return true;
}
