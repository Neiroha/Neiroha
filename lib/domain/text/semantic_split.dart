/// Suggest a semantic split in UTF-16 units without cutting a surrogate pair.
class SemanticSplit {
  static int suggest(String text) {
    if (text.length < 2) return text.length;
    final middle = text.length ~/ 2;
    var best = -1;
    for (final m in RegExp(r'[。！？!?；;，,、…]').allMatches(text)) {
      final at = m.end;
      if (at <= 0 || at >= text.length) continue;
      if (best < 0 || (at - middle).abs() < (best - middle).abs()) best = at;
    }
    var at = best < 0 ? middle : best;
    if (text.codeUnitAt(at - 1) >= 0xD800 &&
        text.codeUnitAt(at - 1) <= 0xDBFF &&
        text.codeUnitAt(at) >= 0xDC00 &&
        text.codeUnitAt(at) <= 0xDFFF) {
      at++;
    }
    return at;
  }
}
