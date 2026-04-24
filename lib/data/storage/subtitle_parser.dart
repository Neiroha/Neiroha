import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

/// A parsed subtitle cue. Times are in milliseconds since the file start.
class ParsedCue {
  final int startMs;
  final int endMs;
  final String text;

  const ParsedCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

/// SRT / LRC parsing. Inputs come from arbitrary text files so we accept
/// BOMs, mixed line endings, and either UTF-8 or GBK-leaning bytes (SRT
/// files from Asian subtitle packs are commonly GBK / Shift-JIS, not UTF-8).
class SubtitleParser {
  SubtitleParser._();

  /// Auto-detect format from extension. Fallback to SRT.
  static Future<List<ParsedCue>> parseFile(File file) async {
    final bytes = await file.readAsBytes();
    final text = _decodeText(bytes);
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.lrc')) return parseLrc(text);
    return parseSrt(text);
  }

  /// Decode bytes, skipping a UTF-8 BOM and falling back to latin1 if the
  /// file contains non-UTF-8 byte sequences (common for legacy SRT packs).
  static String _decodeText(Uint8List bytes) {
    // Strip UTF-8 BOM.
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = Uint8List.sublistView(data, 3);
    }
    try {
      return utf8.decode(data);
    } catch (_) {
      return latin1.decode(data, allowInvalid: true);
    }
  }

  /// Parse an SRT document. Blocks separated by blank lines; each block is:
  /// `<index>` / `HH:MM:SS,mmm --> HH:MM:SS,mmm` / `<text lines>`.
  static List<ParsedCue> parseSrt(String text) {
    final out = <ParsedCue>[];
    final normalised = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalised.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) continue;

      // First line might be the index, or (for malformed files) the timecode.
      final timecodeIdx = _firstTimecodeLine(lines);
      if (timecodeIdx == -1) continue;
      final times = _parseSrtTimecodes(lines[timecodeIdx]);
      if (times == null) continue;
      final cueLines = lines.sublist(timecodeIdx + 1);
      if (cueLines.isEmpty) continue;
      final cueText = cueLines.join('\n').trim();
      if (cueText.isEmpty) continue;
      out.add(ParsedCue(
        startMs: times.$1,
        endMs: times.$2,
        text: _stripTags(cueText),
      ));
    }
    return out;
  }

  static int _firstTimecodeLine(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains('-->')) return i;
    }
    return -1;
  }

  static (int, int)? _parseSrtTimecodes(String line) {
    // `HH:MM:SS,mmm --> HH:MM:SS,mmm` with either `,` or `.` as ms separator.
    final m = RegExp(
      r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
      r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
    ).firstMatch(line);
    if (m == null) return null;
    final start = _hmsMsToMs(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!.padRight(3, '0')),
    );
    final end = _hmsMsToMs(
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
      int.parse(m.group(7)!),
      int.parse(m.group(8)!.padRight(3, '0')),
    );
    return (start, end);
  }

  /// Parse an LRC document. LRC has no explicit end time, so each cue runs
  /// until the next cue's start, and the last cue gets a 3-second fallback.
  /// Multi-timestamp lines like `[00:10.00][00:20.00]hello` are expanded.
  static List<ParsedCue> parseLrc(String text) {
    final normalised = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final pending = <({int startMs, String text})>[];

    for (final raw in normalised.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // `[ar:...]`, `[ti:...]`, `[by:...]` metadata — skip.
      if (RegExp(r'^\[[a-zA-Z]{2}:').hasMatch(line)) continue;

      final matches =
          RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]')
              .allMatches(line)
              .toList();
      if (matches.isEmpty) continue;
      final lyric = line.substring(matches.last.end).trim();
      if (lyric.isEmpty) continue;
      for (final m in matches) {
        final mins = int.parse(m.group(1)!);
        final secs = int.parse(m.group(2)!);
        final msGroup = m.group(3);
        final ms = msGroup == null ? 0 : int.parse(msGroup.padRight(3, '0'));
        pending.add((
          startMs: _hmsMsToMs(0, mins, secs, ms),
          text: _stripTags(lyric),
        ));
      }
    }
    pending.sort((a, b) => a.startMs.compareTo(b.startMs));
    final out = <ParsedCue>[];
    for (var i = 0; i < pending.length; i++) {
      final cur = pending[i];
      final nextStart = i + 1 < pending.length
          ? pending[i + 1].startMs
          : cur.startMs + 3000;
      out.add(ParsedCue(
        startMs: cur.startMs,
        endMs: nextStart,
        text: cur.text,
      ));
    }
    return out;
  }

  static int _hmsMsToMs(int h, int m, int s, int ms) =>
      ((h * 3600) + (m * 60) + s) * 1000 + ms;

  /// Drop basic SRT styling tags (`<b>`, `{i}`, etc.) so they don't appear
  /// in the TTS-spoken text.
  static String _stripTags(String text) =>
      text.replaceAll(RegExp(r'<[^>]+>|\{[^}]+\}'), '').trim();
}
