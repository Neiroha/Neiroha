import 'package:neiroha/domain/novel/role_evaluation.dart';

List<String> evaluationChapters(Map<String, dynamic> fixture) {
  final text = fixture['text'] as String;
  final raw = fixture['chapters'];
  if (raw == null) return [text];
  final chapters = (raw as List).cast<String>();
  if (chapters.isEmpty ||
      chapters.any((s) => s.trim().isEmpty) ||
      chapters.join() != text) {
    throw const FormatException(
      'Chapter slices must concatenate to the original fixture text.',
    );
  }
  return chapters;
}

/// Identity checks use database IDs independently of spelling and aliases.
List<Map<String, Object?>> evaluateIdentityChecks({
  required Map<String, dynamic> fixture,
  required List<Map<String, Object?>> labels,
}) {
  final text = fixture['text'] as String;
  final checks = fixture['identityChecks'] as List? ?? [];
  final chapterEnds = <int>[];
  var chapterEnd = 0;
  for (final chapter in evaluationChapters(fixture)) {
    chapterEnd += chapter.length;
    chapterEnds.add(chapterEnd);
  }
  final results = <Map<String, Object?>>[];
  for (final check in checks) {
    final matches = (check['matches'] as List).cast<String>();
    final kind = check['kind'] as String;
    if (matches.isEmpty || (kind != 'unassigned' && matches.length < 2)) {
      throw const FormatException('Identity check lacks enough anchors.');
    }
    final observed = <Set<Object?>>[];
    final chapterIndices = <int>{};
    for (final match in matches) {
      final offset = text.indexOf(match);
      if (match.isEmpty || offset < 0 || text.indexOf(match, offset + 1) >= 0) {
        throw FormatException('Identity anchor must be unique: $match');
      }
      final end = offset + match.length;
      chapterIndices.add(chapterEnds.indexWhere((end) => end > offset));
      final span = labels
          .where((p) => (p['start'] as int) < end && (p['end'] as int) > offset)
          .toList();
      if (span.isEmpty || span.any((p) => p['kind'] != 'dialogue')) {
        observed.add({});
      } else {
        observed.add(span.map((p) => p['characterId']).toSet());
      }
    }
    final assigned = observed.every(
      (ids) => ids.length == 1 && ids.single != null,
    );
    final distinct = observed.expand((ids) => ids).toSet().length;
    final passed = switch (kind) {
      'same' => assigned && distinct == 1,
      'distinct' => assigned && distinct == matches.length,
      'unassigned' => observed.every(
        (ids) => ids.length == 1 && ids.single == null,
      ),
      _ => throw FormatException('Unknown identity check: $kind'),
    };
    results.add({
      'kind': kind,
      'matches': matches,
      'passed': passed,
      'crossChapter': chapterIndices.length > 1,
      'observedIds': observed.map((ids) => ids.toList()).toList(),
    });
  }
  return results;
}

List<Map<String, Object?>> scoreCapturedIdentity(
  Map<String, dynamic> fixture,
  List<RolePrediction> predictions,
  Map<dynamic, dynamic> annotations,
) {
  final labels = <Map<String, Object?>>[];
  for (final (i, p) in predictions.indexed) {
    final annotation = annotations['${fixture['id']}-$i'];
    if (annotation is! Map || !annotation.containsKey('characterId')) {
      throw const FormatException(
        'Identity scoring requires captured database IDs.',
      );
    }
    labels.add({
      'start': p.start,
      'end': p.end,
      'kind': p.kind.name,
      'characterId': annotation['characterId'],
    });
  }
  return evaluateIdentityChecks(fixture: fixture, labels: labels);
}

void writeIdentityComparison(
  StringBuffer buffer,
  List<Map<String, dynamic>> rows,
) {
  final withChecks = rows.where(
    (r) => (r['identityChecks'] as List).isNotEmpty,
  );
  if (withChecks.isEmpty) return;
  buffer.writeln('\n| 数据库角色 ID 检查 | 基线 | 候选 |\n|---|---:|---:|');
  final categories = {
    '跨章复用同一 ID': (Map c) => c['kind'] == 'same' && c['crossChapter'] == true,
    '同章复用同一 ID': (Map c) => c['kind'] == 'same' && c['crossChapter'] == false,
    '不同人物保持不同 ID': (Map c) => c['kind'] == 'distinct',
    '证据不足时保留空白角色': (Map c) => c['kind'] == 'unassigned',
  };
  for (final entry in categories.entries) {
    String result(String variant) {
      final checks = withChecks
          .where((r) => r['variant'] == variant)
          .expand((r) => r['identityChecks'] as List)
          .where((c) => entry.value(c as Map))
          .toList();
      return '${checks.where((c) => c['passed'] == true).length}/${checks.length}';
    }

    buffer.writeln(
      '| ${entry.key} | ${result('baseline')} | ${result('candidate')} |',
    );
  }
}
