import 'package:neiroha/domain/ai/ai.dart';

final _timed = RegExp(r'^\[(\d+(?:\.\d+)?)?:(\d+(?:\.\d+)?)?\]\s*(.*)$');
final _section = RegExp(r'^\[\[([^\]]+)\]\]$');

Duration? _seconds(String? raw) => raw == null
    ? null
    : Duration(microseconds: (double.parse(raw) * 1e6).round());

/// Parses Lyria lyric text. Clip returns `[1.5:6.0] line`, Lyria 3.5
/// `[[A0]]` section markers with untimed `[:] line`s; anything else is a
/// plain line.
List<LyricLine> parseLyriaLyrics(String raw) {
  String? section;
  final lines = <LyricLine>[];
  for (final line in raw.split('\n').map((l) => l.trim())) {
    if (line.isEmpty) continue;
    final s = _section.firstMatch(line);
    if (s != null) {
      section = s[1];
      continue;
    }
    final t = _timed.firstMatch(line);
    if (t != null) {
      if (t[3]!.trim().isEmpty) continue;
      lines.add(
        LyricLine(
          t[3]!.trim(),
          start: _seconds(t[1]),
          end: _seconds(t[2]),
          section: section,
        ),
      );
    } else {
      lines.add(LyricLine(line, section: section));
    }
  }
  return lines;
}

/// `[mm:ss.xx]` LRC for timed lines; null when no line has a start.
String? lyricsToLrc(List<LyricLine> lines, {String? title}) {
  if (!lines.any((l) => l.start != null)) return null;
  String stamp(Duration d) {
    final cs = (d.inMilliseconds / 10).round();
    final m = cs ~/ 6000, s = (cs % 6000) / 100;
    return '[${m.toString().padLeft(2, '0')}:'
        '${s.toStringAsFixed(2).padLeft(5, '0')}]';
  }

  return [
    if (title != null && title.isNotEmpty) '[ti:$title]',
    for (final l in lines)
      if (l.start != null) '${stamp(l.start!)}${l.text}',
  ].join('\n');
}
