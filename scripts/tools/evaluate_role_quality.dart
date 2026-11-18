import 'dart:convert';
import 'dart:io';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/domain/novel/role_review_evaluation.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';
import '../tests/support/role_eval_fixture.dart';

Map<String, dynamic> read(File f) =>
    jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
double? ratio(int n, int d) => d == 0 ? null : n / d;
String percent(Object? n) =>
    n == null ? '—' : '${((n as num) * 100).toStringAsFixed(1)}%';

/// Compare frozen, repeated experiments offline. Failures remain visible.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart scripts/tools/evaluate_role_quality.dart <matrix directory>',
    );
    exitCode = 64;
    return;
  }
  final root = Directory(args.single);
  final fixtures = {
    for (final f in Directory(
      '${root.path}/fixtures',
    ).listSync().whereType<File>())
      read(f)['id'] as String: read(f),
  };
  final rows = <Map<String, dynamic>>[];
  final failures = <Map<String, Object?>>[];
  final predictions = <String, List<RolePrediction>>{};
  for (final variant in ['baseline', 'candidate']) {
    for (var run = 1; run <= 3; run++) {
      final folder = Directory('${root.path}/$variant/run-$run');
      for (final entry in fixtures.entries) {
        final id = entry.key, fixture = entry.value;
        final artifact = File('${folder.path}/$id.json'),
            metricsFile = File('${folder.path}/$id.metrics.json');
        if (!metricsFile.existsSync()) {
          failures.add({
            'variant': variant,
            'run': run,
            'id': id,
            'status': 'missing',
          });
          continue;
        }
        final metrics = read(metricsFile);
        if (metrics['status'] != 'completed' || !artifact.existsSync()) {
          failures.add({
            'variant': variant,
            'run': run,
            'id': id,
            'status': metrics['status'] ?? 'incomplete',
            'error': metrics['error'],
          });
          continue;
        }
        final capture = read(artifact);
        final text = fixture['text'] as String;
        final gold = (fixture['gold'] as List).cast<Map<String, dynamic>>();
        final roster = (fixture['roster'] as List).cast<Map<String, dynamic>>();
        final after = (capture['labels'] as List)
            .map(
              (p) =>
                  RolePrediction.fromJson(Map<String, dynamic>.from(p as Map)),
            )
            .toList();
        var offset = 0;
        final pieces = <({int start, int end})>[];
        for (final chapter in evaluationChapters(fixture)) {
          for (final part in NovelSemanticSegmenter.split(chapter)) {
            pieces.add((start: part.start + offset, end: part.end + offset));
          }
          offset += chapter.length;
        }
        final beforeLabels = <String, Map>{}, reviewed = <String>{};
        final requests = (metrics['requests'] as List)
            .cast<Map<String, dynamic>>();
        for (final request in requests) {
          final labels = (request['output'] as Map?)?['labels'];
          if (labels is! List) continue;
          if (request['stage'] == 'novel_labelChunk') {
            for (final label in labels) {
              beforeLabels.putIfAbsent(
                label['id'] as String,
                () => label as Map,
              );
            }
          } else if (request['stage'] == 'novel_review') {
            reviewed.addAll(labels.map((l) => l['id'] as String));
          }
        }
        final cast = (capture['characters'] as List)
            .cast<Map<String, dynamic>>();
        String? canonical(Object? name) {
          if (name == null) return null;
          final matches = cast
              .where(
                (c) =>
                    c['name'] == name || (c['aliases'] as List).contains(name),
              )
              .toList();
          return matches.length == 1 ? matches.single['name'] as String : null;
        }

        final before = <RolePrediction>[];
        final flagged = <({int start, int end})>[];
        for (var i = 0; i < pieces.length; i++) {
          final p = pieces[i], label = beforeLabels['$id-$i'];
          if (label == null) {
            throw FormatException(
              'No executor capture for $variant/$run/$id/$i',
            );
          }
          before.add(
            RolePrediction(
              p.start,
              p.end,
              NovelSegmentKind.values.byName(label['kind'] as String),
              canonical(label['characterName']),
            ),
          );
          if (reviewed.contains('$id-$i')) {
            flagged.add((start: p.start, end: p.end));
          }
        }
        final evaluation = RoleEvaluation.evaluate(
          text: text,
          gold: gold,
          roster: roster,
          predictions: after,
        );
        final annotations = {
          for (final a in (capture['annotations'] as List? ?? [])) a['id']: a,
        };
        final identity = fixture['identityChecks'] == null
            ? <Map<String, Object?>>[]
            : scoreCapturedIdentity(fixture, after, annotations);
        final review = RoleReviewEvaluation.compare(
          text: text,
          gold: gold,
          roster: roster,
          before: before,
          after: after,
          predictedCast: cast,
          flagged: flagged,
        );
        final tokens = requests.fold<int>(
          0,
          (n, r) => n + ((r['usage'] as Map?)?['total_tokens'] as int? ?? 0),
        );
        final elapsed = requests.fold<int>(
          0,
          (n, r) => n + (r['elapsedMs'] as int? ?? 0),
        );
        final row = <String, dynamic>{
          'variant': variant,
          'run': run,
          'id': id,
          'skill': capture['skill'],
          'model': capture['model'],
          'score': evaluation.toJson(),
          'review': review,
          'identityChecks': identity,
          'calls': requests.where((r) => r['output'] != null).length,
          'reportedTokens': tokens,
          'requestElapsedMs': elapsed,
          'segments': pieces.length,
          'characters': cast,
          'prediction': after
              .map(
                (p) => {
                  'start': p.start,
                  'end': p.end,
                  'kind': p.kind.name,
                  'speaker': p.speaker,
                },
              )
              .toList(),
        };
        rows.add(row);
        predictions['$variant/$run/$id'] = after;
      }
    }
  }
  final summaries = <String, Map<String, dynamic>>{};
  for (final variant in ['baseline', 'candidate']) {
    final selected = rows.where((r) => r['variant'] == variant).toList();
    int sum(String key) => selected.fold<int>(0, (n, r) => n + (r[key] as int));
    int scoreSum(String key) =>
        selected.fold<int>(0, (n, r) => n + ((r['score'] as Map)[key] as int));
    int reviewSum(String key) =>
        selected.fold<int>(0, (n, r) => n + ((r['review'] as Map)[key] as int));
    var agreeing = 0, comparable = 0;
    for (final entry in fixtures.entries) {
      final runs = [
        for (var run = 1; run <= 3; run++)
          if (predictions['$variant/$run/${entry.key}'] != null)
            predictions['$variant/$run/${entry.key}']!,
      ];
      if (runs.length < 2) continue;
      final metrics = RoleReviewEvaluation.compare(
        text: entry.value['text'] as String,
        gold: (entry.value['gold'] as List).cast<Map<String, dynamic>>(),
        roster: (entry.value['roster'] as List).cast<Map<String, dynamic>>(),
        before: runs.first,
        after: runs.last,
        runs: runs,
      );
      agreeing += metrics['agreeingPairs'] as int;
      comparable += metrics['comparablePairs'] as int;
    }
    final tp = reviewSum('doubtTruePositive'),
        fp = reviewSum('doubtFalsePositive'),
        fn = reviewSum('doubtFalseNegative');
    summaries[variant] = {
      'completed': selected.length,
      'expected': fixtures.length * 3,
      'evaluated': scoreSum('evaluated'),
      'categoryCorrect': scoreSum('categoryCorrect'),
      'categoryAccuracy': ratio(
        scoreSum('categoryCorrect'),
        scoreSum('evaluated'),
      ),
      'speakerTotal': scoreSum('speakerTotal'),
      'speakerCorrect': scoreSum('speakerCorrect'),
      'speakerAccuracy': ratio(
        scoreSum('speakerCorrect'),
        scoreSum('speakerTotal'),
      ),
      'characterRecall': ratio(
        reviewSum('recalledIdentities'),
        reviewSum('goldIdentities'),
      ),
      'duplicateIdentities': reviewSum('duplicateIdentities'),
      'ambiguousIdentities': reviewSum('ambiguousPredictedIdentities'),
      'corrected': reviewSum('corrected'),
      'harmed': reviewSum('harmed'),
      'netGain': reviewSum('netGain'),
      'doubtPrecision': ratio(tp, tp + fp),
      'doubtRecall': ratio(tp, tp + fn),
      'runAgreement': ratio(agreeing, comparable),
      'comparablePairs': comparable,
      'calls': sum('calls'),
      'reportedTokens': sum('reportedTokens'),
      'requestElapsedMs': sum('requestElapsedMs'),
    };
  }
  // Same-case, same-repeat pairs keep missing runs from flattering a candidate.
  final paired = <Map<String, Object?>>[];
  for (final entry in fixtures.entries) {
    for (var run = 1; run <= 3; run++) {
      final b = rows
          .where(
            (r) =>
                r['variant'] == 'baseline' &&
                r['id'] == entry.key &&
                r['run'] == run,
          )
          .firstOrNull;
      final c = rows
          .where(
            (r) =>
                r['variant'] == 'candidate' &&
                r['id'] == entry.key &&
                r['run'] == run,
          )
          .firstOrNull;
      if (b == null || c == null) continue;
      paired.add({
        'id': entry.key,
        'run': run,
        'speakerDelta':
            (c['score']['speakerCorrect'] as int) -
            (b['score']['speakerCorrect'] as int),
        'categoryDelta':
            (c['score']['categoryCorrect'] as int) -
            (b['score']['categoryCorrect'] as int),
        'baselineScore': b['score'],
        'candidateScore': c['score'],
        'tokenDelta':
            (c['reportedTokens'] as int) - (b['reportedTokens'] as int),
      });
    }
  }
  final ledger = read(
    File(
      Platform.environment['NEIROHA_EVAL_BUDGET_FILE'] ??
          '${root.path}/budget.json',
    ),
  );
  final allBudgetRows = ledger['requests'] as List;
  final firstReceipt = int.parse(
    Platform.environment['NEIROHA_EVAL_START_RECEIPT'] ?? '0',
  );
  RangeError.checkValueInInterval(
    firstReceipt,
    0,
    allBudgetRows.length,
    'first receipt',
  );
  final budgetRows = allBudgetRows.skip(firstReceipt).toList();
  final charged = budgetRows.fold<int>(
    0,
    (n, r) => n + (r['chargedMicroUsd'] as int),
  );
  final knownEstimate = budgetRows.fold<int>(
    0,
    (n, r) => n + (r['standardPriceUpperMicroUsd'] as int? ?? 0),
  );
  final cumulativeCharge = allBudgetRows.fold<int>(
    0,
    (n, r) => n + (r['chargedMicroUsd'] as int),
  );
  String version(String variant) => NovelRoleSkill.parse(
    File('${root.path}/$variant-SKILL.md').readAsStringSync(),
  ).version;
  final oldFailures = Directory('${root.path}/failed-attempts');
  final report = <String, Object?>{
    'model': 'gpt-6-luna',
    'summaries': summaries,
    'pairedCompleted': paired.length,
    'paired': paired,
    'rows': rows,
    'failures': failures,
    'budget': {
      'limitUsd': 50,
      'attemptedCalls': budgetRows.length,
      'conservativeChargeUsd': charged / 1e6,
      'cumulativeConservativeChargeUsd': cumulativeCharge / 1e6,
      'firstReceipt': firstReceipt,
      'knownStandardUpperEstimateUsd': knownEstimate / 1e6,
      'unknownUsageCalls': budgetRows.where((r) => r['usage'] == null).length,
      'archivedCaptureFiles': oldFailures.existsSync()
          ? oldFailures.listSync().length
          : 0,
      'includesPilotsAndFailures': true,
      'pricingSource':
          'https://developers.openai.com/api/docs/models/gpt-6-luna',
    },
  };
  File(
    '${root.path}/comparison.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  final md = StringBuffer('# 分角质量矩阵对比\n\n')
    ..writeln(
      'gpt-6-luna；${fixtures.length} 种文本 × 3 次 × 两个候选，共 ${fixtures.length * 6} 个计划运行；完整配对 ${paired.length}/${fixtures.length * 3}。金标未进入模型输入，未人工改名对齐。',
    )
    ..writeln(
      '\n| 指标 | 基线 ${version('baseline')} | 候选 ${version('candidate')} |\n|---|---:|---:|',
    );
  void line(
    String label,
    Object? Function(Map<String, dynamic>) value,
  ) => md.writeln(
    '| $label | ${value(summaries['baseline']!)} | ${value(summaries['candidate']!)} |',
  );
  line('完成/计划', (m) => '${m['completed']}/${m['expected']}');
  line(
    '类别',
    (m) =>
        '${m['categoryCorrect']}/${m['evaluated']} (${percent(m['categoryAccuracy'])})',
  );
  line(
    '人物严格匹配',
    (m) =>
        '${m['speakerCorrect']}/${m['speakerTotal']} (${percent(m['speakerAccuracy'])})',
  );
  line('人物召回', (m) => percent(m['characterRecall']));
  line(
    '重复身份 / 歧义映射',
    (m) => '${m['duplicateIdentities']} / ${m['ambiguousIdentities']}',
  );
  line(
    'Reviewer 改对 / 改坏 / 净收益',
    (m) => '${m['corrected']} / ${m['harmed']} / ${m['netGain']}',
  );
  line(
    '送审精确率 / 召回率',
    (m) => '${percent(m['doubtPrecision'])} / ${percent(m['doubtRecall'])}',
  );
  line('跨轮标签一致率', (m) => percent(m['runAgreement']));
  line('成功调用 / Tokens', (m) => '${m['calls']} / ${m['reportedTokens']}');
  line(
    '请求耗时合计（秒）',
    (m) => ((m['requestElapsedMs'] as int) / 1000).toStringAsFixed(1),
  );
  md.writeln(
    '\n| 配置/轮次 | 完成 | 类别正确/总数 | 人物正确/总数 | Tokens |\n|---|---:|---:|---:|---:|',
  );
  for (final variant in ['baseline', 'candidate']) {
    for (var run = 1; run <= 3; run++) {
      final group = rows
          .where((r) => r['variant'] == variant && r['run'] == run)
          .toList();
      int score(String key) =>
          group.fold<int>(0, (n, r) => n + (r['score'][key] as int));
      final tokens = group.fold<int>(
        0,
        (n, r) => n + (r['reportedTokens'] as int),
      );
      md.writeln(
        '| $variant/$run | ${group.length}/${fixtures.length} | ${score('categoryCorrect')}/${score('evaluated')} | ${score('speakerCorrect')}/${score('speakerTotal')} | $tokens |',
      );
    }
  }
  md.writeln(
    '\n| 文本 | 配对人物差值（候选−基线） | 类别差值 | Token 差值 |\n|---|---:|---:|---:|',
  );
  for (final id in fixtures.keys) {
    final group = paired.where((p) => p['id'] == id).toList();
    int sum(String key) => group.fold<int>(0, (n, r) => n + (r[key] as int));
    md.writeln(
      '| $id (${group.length}/3) | ${sum('speakerDelta')} | ${sum('categoryDelta')} | ${sum('tokenDelta')} |',
    );
  }
  writeIdentityComparison(md, rows);
  md.writeln(
    '\n本轮账本从第 $firstReceipt 条收据起统计，包含 ${budgetRows.length} 次请求尝试。保守预算占用 \$${(charged / 1e6).toStringAsFixed(4)}，累计 \$${(cumulativeCharge / 1e6).toStringAsFixed(4)} / \$50。已知 usage 的标准价格上界估算为 \$${(knownEstimate / 1e6).toStringAsFixed(4)}，${budgetRows.where((r) => r['usage'] == null).length} 次未知用量保留预留。定价依据见[官方 Luna 页面](https://developers.openai.com/api/docs/models/gpt-6-luna)。',
  );
  md.writeln(
    '\n完成率、准确率分母与配对数分别展示。失败不算通过；未完成范围没有准确率。送审指标包含 inferred 抽查，只在有金标范围计分，不等于纯规则检测器精度。跨轮一致率按金标范围内的边界、类别和人物标签比较，名称没有人工对齐。正文完整 UTF-16 分区是硬约束。',
  );
  md.writeln('\n预跑与失败捕获在相应目录中保留。对比矩阵共用同一运行时。耗时受传输路径与并发影响。');
  md.writeln(
    '\n嵌套引语存在表演策略差异：部分金标采用故事人物，部分采用实际讲述者；严格分数保留这些差异，应用可通过用户配音意图明确选择。多轮结果反映本集，不保证所有题材。原文、金标、技能快照、原始输出、usage 与逐项错误见相邻 JSON 和各 run 目录。',
  );
  if (failures.isNotEmpty) {
    md.writeln('\n未完成：');
    for (final f in failures) {
      md.writeln(
        '- ${f['variant']}/${f['run']}/${f['id']}: ${f['status']} ${f['error'] ?? ''}',
      );
    }
  }
  File('${root.path}/comparison.md').writeAsStringSync('$md');
  final mistakes = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final fixture = fixtures[row['id']]!;
    final labels = (row['prediction'] as List)
        .map(
          (p) => RolePrediction.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList();
    for (final gold in (fixture['gold'] as List).cast<Map<String, dynamic>>()) {
      final e = RoleEvaluation.evaluate(
        text: fixture['text'] as String,
        gold: [gold],
        roster: (fixture['roster'] as List).cast<Map<String, dynamic>>(),
        predictions: labels,
      );
      if (e.failures.isEmpty) continue;
      final key = '${row['id']}|${gold['match']}';
      final m = mistakes.putIfAbsent(
        key,
        () => {'id': row['id'], 'gold': gold, 'baseline': 0, 'candidate': 0},
      );
      m[row['variant'] as String] = (m[row['variant']] as int) + 1;
    }
  }
  final worst = mistakes.values.toList()
    ..sort((a, b) => (b['candidate'] as int).compareTo(a['candidate'] as int));
  final errors = StringBuffer('# 分角错例汇总\n\n')
    ..writeln(
      '每项按三轮中严格评分失败次数统计，分母以 comparison.md 的完成数为准。未做人工同人改名；匿名名称和嵌套表演策略也可能导致严格失败。\n',
    )
    ..writeln(
      '| 文本 | 金标原句（节选） | 要求人物/类别 | 基线失败 | 候选失败 |\n|---|---|---|---:|---:|',
    );
  for (final m in worst) {
    final g = m['gold'] as Map;
    final excerpt = String.fromCharCodes(
      (g['match'] as String).runes.take(100),
    ).replaceAll('|', '\\|').replaceAll('\n', ' ');
    errors.writeln(
      '| ${m['id']} | $excerpt | ${g['speaker'] ?? '无人物要求'} / ${g['category']} | ${m['baseline']} | ${m['candidate']} |',
    );
  }
  File('${root.path}/errors.md').writeAsStringSync('$errors');
  stdout.writeln(
    'Wrote ${root.path}/comparison.md; ${paired.length} complete pairs; ${failures.length} missing/failed runs.',
  );
}
