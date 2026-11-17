import 'dart:convert';
import 'role_evaluation.dart';

/// Gold-only diagnostics: unlabeled text is never assumed correct/incorrect.
class RoleReviewEvaluation {
  static Map<String, Object?> compare({
    required String text,
    required List<Map<String, dynamic>> gold,
    required List<RolePrediction> before,
    required List<RolePrediction> after,
    List<Map<String, dynamic>> roster = const [],
    List<Map<String, dynamic>> predictedCast = const [],
    List<({int start, int end})> flagged = const [],
    List<List<RolePrediction>> runs = const [],
  }) {
    // Validate complete partitions even when the gold set is empty.
    for (final labels in [before, after, ...runs]) {
      RoleEvaluation.evaluate(
        text: text,
        gold: gold,
        predictions: labels,
        roster: roster,
      );
    }
    var evaluated = 0, excluded = 0, corrected = 0, harmed = 0;
    var truePositive = 0, falsePositive = 0, falseNegative = 0;
    var agreeingPairs = 0, comparablePairs = 0;
    for (final g in gold) {
      final b = RoleEvaluation.evaluate(
        text: text,
        gold: [g],
        predictions: before,
        roster: roster,
      );
      final a = RoleEvaluation.evaluate(
        text: text,
        gold: [g],
        predictions: after,
        roster: roster,
      );
      if (b.evaluated == 0) {
        excluded++;
        continue;
      }
      evaluated++;
      final wasCorrect = b.failures.isEmpty, nowCorrect = a.failures.isEmpty;
      if (!wasCorrect && nowCorrect) corrected++;
      if (wasCorrect && !nowCorrect) harmed++;
      final match = g['match'] as String;
      var start = -1;
      for (
        var occurrence = 0;
        occurrence <= (g['occurrence'] as int? ?? 0);
        occurrence++
      ) {
        start = text.indexOf(match, start + 1);
      }
      final end = start + match.length;
      final detected = flagged.any((s) => s.start < end && s.end > start);
      if (detected && !wasCorrect) truePositive++;
      if (detected && wasCorrect) falsePositive++;
      if (!detected && !wasCorrect) falseNegative++;
      String signature(List<RolePrediction> labels) => jsonEncode([
        for (final p in labels.where((p) => p.start < end && p.end > start))
          [
            p.start.clamp(start, end),
            p.end.clamp(start, end),
            p.kind.name,
            p.speaker,
          ],
      ]);
      for (var i = 0; i < runs.length; i++) {
        for (var j = i + 1; j < runs.length; j++) {
          comparablePairs++;
          if (signature(runs[i]) == signature(runs[j])) agreeingPairs++;
        }
      }
    }
    final matched = <String, int>{};
    var ambiguousIdentities = 0, extraIdentities = 0;
    for (final c in predictedCast) {
      final names = {c['name'], ...(c['aliases'] as List? ?? [])};
      final matches = roster
          .where(
            (g) => {
              g['name'],
              ...(g['aliases'] as List? ?? []),
            }.intersection(names).isNotEmpty,
          )
          .toList();
      if (matches.length == 1) {
        final name = matches.single['name'] as String;
        matched[name] = (matched[name] ?? 0) + 1;
      } else if (matches.length > 1) {
        ambiguousIdentities++;
      } else {
        extraIdentities++;
      }
    }
    double? ratio(int n, int d) => d == 0 ? null : n / d;
    return {
      'evaluated': evaluated,
      'ambiguousGoldExcluded': excluded,
      'corrected': corrected,
      'harmed': harmed,
      'netGain': corrected - harmed,
      'doubtTruePositive': truePositive,
      'doubtFalsePositive': falsePositive,
      'doubtFalseNegative': falseNegative,
      'doubtPrecision': ratio(truePositive, truePositive + falsePositive),
      'doubtRecall': ratio(truePositive, truePositive + falseNegative),
      'goldIdentities': roster.length,
      'recalledIdentities': matched.length,
      'characterRecall': ratio(matched.length, roster.length),
      'duplicateIdentities': matched.values.fold<int>(
        0,
        (sum, n) => sum + n - 1,
      ),
      'ambiguousPredictedIdentities': ambiguousIdentities,
      'unmatchedPredictedIdentities': extraIdentities,
      'runAgreement': ratio(agreeingPairs, comparablePairs),
      'agreeingPairs': agreeingPairs,
      'comparablePairs': comparablePairs,
    };
  }
}
