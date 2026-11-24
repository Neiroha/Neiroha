/// What an ASR read-back heard compared with what the TTS was asked to say.
class SpeechCheck {
  const SpeechCheck({
    required this.expected,
    required this.heard,
    required this.score,
    this.missing = const [],
    this.voiceAssetId,
    this.error,
  });

  /// The text sent to TTS (after translate / rewrite steps).
  final String expected;
  final String heard;

  /// Share of the expected words heard, 0–1.
  final double score;

  /// Runs of expected words the transcript lacks, in order.
  final List<String> missing;
  final String? voiceAssetId;

  /// Why the check could not run (STT failed); [score] is 0 then.
  final Object? error;

  bool get clean => error == null && missing.isEmpty;

  SpeechCheck forAsset(String? id) => SpeechCheck(
    expected: expected,
    heard: heard,
    score: score,
    missing: missing,
    voiceAssetId: id,
    error: error,
  );
}

/// Expected words as units: one per CJK / kana / hangul character, one per
/// run of letters or digits otherwise. Punctuation and spacing are ignored.
List<({String text, bool spaced})> speechUnits(String text) {
  final units = <({String text, bool spaced})>[];
  final word = StringBuffer();
  void flush() {
    if (word.isEmpty) return;
    units.add((text: word.toString(), spaced: true));
    word.clear();
  }

  for (final rune in text.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    if (_isIdeographic(rune)) {
      flush();
      units.add((text: c, spaced: false));
    } else if (RegExp(r"[\p{L}\p{N}']", unicode: true).hasMatch(c)) {
      word.write(c);
    } else {
      flush();
    }
  }
  flush();
  return units;
}

bool _isIdeographic(int r) =>
    (r >= 0x3040 && r <= 0x30FF) || // kana
    (r >= 0x3400 && r <= 0x9FFF) || // CJK
    (r >= 0xAC00 && r <= 0xD7AF) || // hangul
    (r >= 0xF900 && r <= 0xFAFF);

/// Aligns [heard] with [expected] (longest common subsequence of units) and
/// lists the expected runs that were not heard.
SpeechCheck compareSpeech(String expected, String heard) {
  const maxUnits = 2000;
  final a = speechUnits(expected).take(maxUnits).toList();
  final b = speechUnits(heard).take(maxUnits).toList();
  if (a.isEmpty) return SpeechCheck(expected: expected, heard: heard, score: 1);
  // LCS table, one row per expected unit.
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      dp[i][j] = a[i].text == b[j].text
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final missing = <String>[];
  final run = <({String text, bool spaced})>[];
  void close() {
    if (run.isEmpty) return;
    final out = StringBuffer();
    for (final (k, u) in run.indexed) {
      if (k > 0 && u.spaced && run[k - 1].spaced) out.write(' ');
      out.write(u.text);
    }
    missing.add(out.toString());
    run.clear();
  }

  var i = 0, j = 0;
  while (i < a.length) {
    if (j < b.length && a[i].text == b[j].text) {
      close();
      i++;
      j++;
    } else if (j < b.length && dp[i][j + 1] >= dp[i + 1][j]) {
      j++; // extra word in the transcript
    } else {
      run.add(a[i]);
      i++;
    }
  }
  close();
  return SpeechCheck(
    expected: expected,
    heard: heard,
    score: dp[0][0] / a.length,
    missing: missing,
  );
}
