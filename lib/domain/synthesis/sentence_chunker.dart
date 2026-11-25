/// Cuts streamed text into speakable sentences as soon as each one ends, so
/// speech can start before the whole answer exists.
///
/// A sentence ends at `。！？!?…` or a newline (closing quotes and brackets
/// stay with it), or at `.` followed by a space. The first sentence may also
/// end at a comma once it is long enough, which shortens time to first
/// audio; any piece longer than [maxChars] breaks at its last pause. Pieces
/// shorter than [minChars] wait for the next sentence instead of becoming
/// a request of their own.
class SentenceChunker {
  SentenceChunker({
    this.minChars = 2,
    this.firstSoftBreak = 24,
    this.maxChars = 160,
  });

  final int minChars;

  /// Length after which the first sentence may end at a comma.
  final int firstSoftBreak;
  final int maxChars;

  final _buffer = StringBuffer();
  bool _emitted = false;

  static final _strong = RegExp(r'[。！？!?…\n]');
  static final _soft = RegExp(r'[，、,;；：:]');
  static const _closers = '」』”’"\')）】》]';

  /// Sentences completed by [delta], in order.
  List<String> add(String delta) {
    _buffer.write(delta);
    final out = <String>[];
    while (true) {
      final next = _take();
      if (next == null) break;
      out.add(next);
    }
    return out;
  }

  /// The rest of the text once the stream has ended (null when empty).
  String? flush() {
    final rest = _buffer.toString().trim();
    _buffer.clear();
    if (rest.isEmpty) return null;
    _emitted = true;
    return rest;
  }

  String? _take() {
    final text = _buffer.toString();
    var end = _sentenceEnd(text);
    if (end == null && text.length > maxChars) {
      end = _pauseBefore(text, maxChars);
    }
    if (end == null && !_emitted && text.length >= firstSoftBreak) {
      end = _softEnd(text);
    }
    if (end == null) return null;
    final sentence = text.substring(0, end).trim();
    if (sentence.runes.where(_isWordy).length < minChars) {
      // Too short to speak alone ("嗯。"): wait for more unless it is all.
      final later = _sentenceEnd(text, from: end);
      if (later == null) return null;
      end = later;
    }
    final piece = text.substring(0, end).trim();
    _buffer
      ..clear()
      ..write(text.substring(end));
    if (piece.isEmpty) return _take();
    _emitted = true;
    return piece;
  }

  /// End offset (exclusive) of the first complete sentence after [from].
  int? _sentenceEnd(String text, {int from = 0}) {
    for (var i = from; i < text.length; i++) {
      final c = text[i];
      final strong = _strong.hasMatch(c);
      final period =
          c == '.' &&
          i + 1 < text.length &&
          (text[i + 1] == ' ' || text[i + 1] == '\n') &&
          // "3. " in a list or "e.g. " stays inside the sentence.
          i > 0 &&
          !RegExp(r'[0-9]').hasMatch(text[i - 1]) &&
          !(i > 1 && text[i - 2] == '.');
      if (!strong && !period) continue;
      var end = i + 1;
      while (end < text.length &&
          (_closers.contains(text[end]) || _strong.hasMatch(text[end]))) {
        end++;
      }
      // A terminator at the very end may still grow ("!" → "!?" / "…」").
      if (end == text.length && c != '\n') return null;
      return end;
    }
    return null;
  }

  int? _softEnd(String text) {
    int? last;
    for (final m in _soft.allMatches(text)) {
      if (m.end < text.length) last = m.end;
    }
    return last;
  }

  int _pauseBefore(String text, int limit) {
    final head = text.substring(0, limit);
    final soft = _soft.allMatches(head).lastOrNull?.end;
    if (soft != null && soft > limit ~/ 3) return soft;
    final space = head.lastIndexOf(' ');
    return space > limit ~/ 3 ? space + 1 : limit;
  }

  static bool _isWordy(int rune) {
    final c = String.fromCharCode(rune);
    return !_strong.hasMatch(c) &&
        !_soft.hasMatch(c) &&
        !_closers.contains(c) &&
        c.trim().isNotEmpty;
  }
}

/// Sentences of a text stream, emitted as each one completes.
Stream<String> chunkSentences(
  Stream<String> deltas, {
  SentenceChunker? chunker,
}) async* {
  final c = chunker ?? SentenceChunker();
  await for (final delta in deltas) {
    for (final sentence in c.add(delta)) {
      yield sentence;
    }
  }
  if (c.flush() case final String rest) yield rest;
}

/// Sentences of a complete text (same rules as streaming).
List<String> splitSentences(String text, {SentenceChunker? chunker}) {
  final c = chunker ?? SentenceChunker();
  return [...c.add(text), ?c.flush()];
}
