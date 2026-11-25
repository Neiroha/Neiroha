import 'subtitle_cue.dart';

/// Serialises cues as SRT, WebVTT or LRC (lyrics; start times only).
String writeSubtitles(
  List<SubtitleCue> cues,
  SubtitleFormat format, {
  SubtitleTextMode mode = SubtitleTextMode.original,
}) {
  String text(SubtitleCue c) {
    final translated = c.translation?.trim();
    final original = c.text.trim();
    return switch (mode) {
      SubtitleTextMode.original => original,
      SubtitleTextMode.translation =>
        translated?.isNotEmpty == true ? translated! : original,
      SubtitleTextMode.bilingual =>
        translated?.isNotEmpty == true
            ? format == SubtitleFormat.lrc
                  ? '$original / $translated'
                  : '$original\n$translated'
            : original,
    };
  }

  final out = StringBuffer();
  switch (format) {
    case SubtitleFormat.srt:
      for (var i = 0; i < cues.length; i++) {
        out
          ..writeln(i + 1)
          ..writeln(
            '${_clock(cues[i].start, ',')} --> '
            '${_clock(cues[i].end, ',')}',
          )
          ..writeln(text(cues[i]))
          ..writeln();
      }
    case SubtitleFormat.vtt:
      out
        ..writeln('WEBVTT')
        ..writeln();
      for (final c in cues) {
        out
          ..writeln('${_clock(c.start, '.')} --> ${_clock(c.end, '.')}')
          ..writeln(text(c))
          ..writeln();
      }
    case SubtitleFormat.lrc:
      for (final c in cues) {
        final cs = c.start.inMilliseconds ~/ 10;
        final mm = (cs ~/ 6000).toString().padLeft(2, '0');
        final ss = (cs ~/ 100 % 60).toString().padLeft(2, '0');
        final xx = (cs % 100).toString().padLeft(2, '0');
        out.writeln('[$mm:$ss.$xx]${text(c)}');
      }
  }
  return out.toString();
}

String _clock(Duration d, String msSeparator) {
  String two(int v) => v.toString().padLeft(2, '0');
  final ms = d.inMilliseconds;
  return '${two(ms ~/ 3600000)}:${two(ms ~/ 60000 % 60)}:'
      '${two(ms ~/ 1000 % 60)}$msSeparator${(ms % 1000).toString().padLeft(3, '0')}';
}
