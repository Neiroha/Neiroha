/// Semantic units retain the exact source. Audio-length slicing happens later.
class NovelTextSegment {
  const NovelTextSegment({
    required this.text,
    required this.type,
    this.start = 0,
    this.end = 0,
    this.paragraph = 0,
    this.quoteDepth = 0,
    this.channel = 'narration',
    this.senderHint,
  });
  final String text;
  final String type;
  final int start;
  final int end;
  final int paragraph;
  final int quoteDepth;
  final String channel;
  final String? senderHint;

  Map<String, Object?> get structure => {
    'start': start,
    'end': end,
    'paragraph': paragraph,
    'quoteDepth': quoteDepth,
    'channel': channel,
    'senderHint': senderHint,
  };
}

class NovelSemanticSegmenter {
  static const version = 'semantic-v2';
  static const defaultQuotes = {'“': '”', '「': '」', '『': '』', '"': '"'};

  static List<NovelTextSegment> split(
    String text, {
    Map<String, String> quotes = defaultQuotes,
    List<RegExp> extraDialogueRules = const [],
  }) {
    if (text.trim().isEmpty) return const [];
    final ranges = <int, _AtomicRange>{};
    for (final pattern in [RegExp(r'【[^【】]*】'), RegExp(r'\[[^\[\]\r\n]*\]')]) {
      for (final match in pattern.allMatches(text)) {
        final body = match.group(0)!.substring(1, match.group(0)!.length - 1);
        final sender = RegExp(r'^([^：:\r\n]{1,30})[：:]').firstMatch(body);
        if (sender == null) {
          if (RegExp(r'^(叮|系统|宿主|任务|温馨提示)').hasMatch(body)) {
            ranges[match.start] = _AtomicRange(match.end, 'system', null);
          }
          continue;
        }
        final name = sender.group(1)!.trim();
        if (name.isEmpty) continue;
        ranges[match.start] = _AtomicRange(
          match.end,
          name.contains('系统') || name == '温馨提示' ? 'system' : 'chat',
          name,
        );
      }
    }
    for (final regex in extraDialogueRules) {
      for (final match in regex.allMatches(text)) {
        if (match.end > match.start &&
            _boundary(text, match.start) &&
            _boundary(text, match.end) &&
            !RegExp(r'[\r\n“「『"【]').hasMatch(match.group(0)!)) {
          ranges.putIfAbsent(
            match.start,
            () => _AtomicRange(match.end, 'speech', null),
          );
        }
      }
    }
    final out = <NovelTextSegment>[];
    final stack = <String>[];
    var start = 0, paragraph = 0, depth = 0, runParagraph = 0;
    void emit(int end, {String? channel, String? sender}) {
      if (end <= start || text.substring(start, end).trim().isEmpty) return;
      out.add(
        NovelTextSegment(
          text: text.substring(start, end),
          type: depth > 0 || channel == 'speech' || channel == 'chat'
              ? 'dialogue'
              : 'narrator',
          start: start,
          end: end,
          paragraph: runParagraph,
          quoteDepth: depth,
          channel: channel ?? (depth > 0 ? 'speech' : 'narration'),
          senderHint: sender,
        ),
      );
      start = end;
      runParagraph = paragraph;
    }

    for (var i = 0; i < text.length;) {
      final atomic = ranges[i];
      if (atomic != null) {
        emit(i);
        depth = stack.length;
        emit(atomic.end, channel: atomic.channel, sender: atomic.sender);
        paragraph += '\n'.allMatches(text.substring(i, atomic.end)).length;
        runParagraph = paragraph;
        i = atomic.end;
        continue;
      }
      final char = text[i];
      if (stack.isNotEmpty && char == stack.last) {
        emit(i + 1);
        stack.removeLast();
        depth = stack.length;
        i++;
        continue;
      }
      if (quotes.containsKey(char)) {
        emit(i);
        stack.add(quotes[char]!);
        depth = stack.length;
        i++;
        continue;
      }
      if (char == '\n' || char == '\r') {
        final end = char == '\r' && i + 1 < text.length && text[i + 1] == '\n'
            ? i + 2
            : i + 1;
        var next = end;
        while (next < text.length && text[next].trim().isEmpty) {
          next++;
        }
        // Keep a detached closing delimiter attached to its own utterance.
        if (stack.isEmpty || next >= text.length || text[next] != stack.last) {
          emit(end);
        }
        paragraph++;
        if (start == end || text.substring(start, end).trim().isEmpty) {
          runParagraph = paragraph;
        }
        i = end;
        continue;
      }
      if (stack.isEmpty && '。！？!?；;'.contains(char)) emit(i + 1);
      final unit = text.codeUnitAt(i);
      i += unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.length ? 2 : 1;
    }
    emit(text.length);
    if (start < text.length && out.isNotEmpty) {
      final last = out.removeLast();
      out.add(
        NovelTextSegment(
          text: text.substring(last.start),
          type: last.type,
          start: last.start,
          end: text.length,
          paragraph: last.paragraph,
          quoteDepth: last.quoteDepth,
          channel: last.channel,
          senderHint: last.senderHint,
        ),
      );
    }
    return out;
  }

  static bool _boundary(String text, int at) =>
      at == 0 ||
      at == text.length ||
      !(text.codeUnitAt(at - 1) >= 0xD800 &&
          text.codeUnitAt(at - 1) <= 0xDBFF &&
          text.codeUnitAt(at) >= 0xDC00 &&
          text.codeUnitAt(at) <= 0xDFFF);
}

class _AtomicRange {
  const _AtomicRange(this.end, this.channel, this.sender);
  final int end;
  final String channel;
  final String? sender;
}
