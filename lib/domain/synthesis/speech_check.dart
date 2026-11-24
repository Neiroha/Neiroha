/// What an ASR read-back heard compared with what the TTS was asked to say.
class SpeechCheck {
  const SpeechCheck({
    required this.expected,
    required this.heard,
    required this.score,
    this.missing = const [],
    this.extra = const [],
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

  /// Runs of [extraFrom]+ words heard that the text does not have, e.g. a
  /// conversational model's "All right, let me read that".
  final List<String> extra;
  final String? voiceAssetId;

  /// Why the check could not run (STT failed); [score] is 0 then.
  final Object? error;

  /// Shorter unmatched runs are ASR noise (fillers, particles).
  static const extraFrom = 4;

  bool get clean => error == null && missing.isEmpty && extra.isEmpty;

  SpeechCheck forAsset(String? id) => SpeechCheck(
    expected: expected,
    heard: heard,
    score: score,
    missing: missing,
    extra: extra,
    voiceAssetId: id,
    error: error,
  );
}

/// One unit of speech: its text as written, and the [key] it is compared
/// by (numbers as digits, homophones ASR cannot tell apart folded).
typedef SpeechUnit = ({String text, bool spaced, String key});

/// Units: one per CJK / kana / hangul character (a run of CJK numerals is
/// one number), one per run of letters or digits otherwise. Punctuation
/// and spacing are ignored.
List<SpeechUnit> speechUnits(String text) {
  final units = <SpeechUnit>[];
  final word = StringBuffer();
  final number = StringBuffer();
  void flushWord() {
    if (word.isEmpty) return;
    final w = word.toString();
    units.add((text: w, spaced: true, key: _wordKey(w)));
    word.clear();
  }

  void flushNumber() {
    if (number.isEmpty) return;
    final n = number.toString();
    // A lone 一 / 两 is usually not a number (一起, 两边): keep it a char.
    final value = n.length == 1 && '一两'.contains(n) ? null : _cjkNumber(n);
    units.add((text: n, spaced: false, key: value?.toString() ?? n));
    number.clear();
  }

  for (final rune in text.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    if (_cjkDigits.containsKey(c) || _cjkUnits.containsKey(c)) {
      flushWord();
      number.write(c);
      continue;
    }
    flushNumber();
    if (_isIdeographic(rune)) {
      flushWord();
      units.add((text: c, spaced: false, key: _homophones[c] ?? c));
    } else if (RegExp(r"[\p{L}\p{N}']", unicode: true).hasMatch(c)) {
      // Letters and digits split: "9時" and "3pm" compare the number.
      final digit = RegExp(r'\d').hasMatch(c);
      if (word.isNotEmpty &&
          RegExp(r'\d').hasMatch(word.toString()[0]) != digit) {
        flushWord();
      }
      word.write(c);
    } else {
      flushWord();
    }
  }
  flushWord();
  flushNumber();
  return units;
}

bool _isKana(int r) => r >= 0x3040 && r <= 0x30FF;
bool _isKanji(int r) =>
    (r >= 0x3400 && r <= 0x9FFF) || (r >= 0xF900 && r <= 0xFAFF);

bool _isIdeographic(int r) =>
    (r >= 0x3040 && r <= 0x30FF) || // kana
    (r >= 0x3400 && r <= 0x9FFF) || // CJK
    (r >= 0xAC00 && r <= 0xD7AF) || // hangul
    (r >= 0xF900 && r <= 0xFAFF);

/// Characters ASR picks between by guess: same sound, same role.
const _homophones = {'她': '他', '它': '他', '祂': '他', '地': '的', '得': '的'};

const _cjkDigits = {
  '〇': 0, '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, //
  '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
};
const _cjkUnits = {'十': 10, '百': 100, '千': 1000, '万': 10000};

/// 二十五 → 25, 一百零三 → 103, 二〇二六 → 2026; null if not a number.
int? _cjkNumber(String s) {
  if (!s.split('').any(_cjkUnits.containsKey)) {
    // Digit by digit, as years and phone numbers are read.
    return int.tryParse(s.split('').map((c) => _cjkDigits[c]).join());
  }
  var total = 0, section = 0, digit = 0;
  for (final c in s.split('')) {
    if (_cjkDigits[c] case final d?) {
      digit = d;
    } else if (_cjkUnits[c] case final u?) {
      if (u == 10000) {
        total += (section + digit) * u;
        section = 0;
      } else {
        section += (digit == 0 ? 1 : digit) * u;
      }
      digit = 0;
    }
  }
  return total + section + digit;
}

const _numberWords = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
  'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
  'seventy': 70, 'eighty': 80, 'ninety': 90, 'hundred': 100,
};

String _wordKey(String w) {
  if (_numberWords[w] case final n?) return '$n';
  if (int.tryParse(w) case final n?) return '$n';
  return w;
}

String _join(List<SpeechUnit> run) {
  final out = StringBuffer();
  for (final (k, u) in run.indexed) {
    if (k > 0 && u.spaced && run[k - 1].spaced) out.write(' ');
    out.write(u.text);
  }
  return out.toString();
}

/// Aligns [heard] with [expected] (longest common subsequence of units) and
/// lists the expected runs that were not heard, and long runs heard that
/// the text does not have.
SpeechCheck compareSpeech(String expected, String heard) {
  const maxUnits = 2000;
  final a = speechUnits(expected).take(maxUnits).toList();
  final b = speechUnits(heard).take(maxUnits).toList();
  if (a.isEmpty) return SpeechCheck(expected: expected, heard: heard, score: 1);
  // LCS table, one row per expected unit.
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      dp[i][j] = a[i].key == b[j].key
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] >= dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final missing = <String>[], extra = <String>[];
  final lost = <SpeechUnit>[], added = <SpeechUnit>[];
  var forgiven = 0; // kanji heard as kana
  // Closes the gap between two matched units.
  void closeGap() {
    // Kanji written out in kana (引き出し → ひきだし) is the same reading.
    final notation =
        lost.isNotEmpty &&
        added.length >= lost.length &&
        lost.every((u) => _isKanji(u.text.runes.first)) &&
        added.every((u) => _isKana(u.text.runes.first));
    if (notation) {
      forgiven += lost.length;
    } else {
      if (lost.isNotEmpty) missing.add(_join(lost));
      if (added.length >= SpeechCheck.extraFrom) extra.add(_join(added));
    }
    lost.clear();
    added.clear();
  }

  var i = 0, j = 0;
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i].key == b[j].key) {
      closeGap();
      i++;
      j++;
    } else if (j < b.length &&
        (i == a.length || dp[i][j + 1] >= dp[i + 1][j])) {
      added.add(b[j++]); // heard, not in the text
    } else {
      lost.add(a[i++]);
    }
  }
  closeGap();
  return SpeechCheck(
    expected: expected,
    heard: heard,
    score: (dp[0][0] + forgiven) / a.length,
    missing: missing,
    extra: extra,
  );
}
