import 'dart:convert';
import 'dart:io';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/domain/novel/role_review_evaluation.dart';
import 'package:neiroha/domain/novel/role_models.dart';

/// Offline scoring of captured local review. Never reads .env or calls a model.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run scripts/tools/evaluate_role_review.dart <capture.json>',
    );
    exitCode = 64;
    return;
  }
  final file = File(args.single);
  final capture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final results = <Map<String, Object?>>[];
  for (final c in (capture['cases'] as List).cast<Map<String, dynamic>>()) {
    final id = c['id'] as String;
    final fixture =
        jsonDecode(
              File(
                'scripts/tests/fixtures/role_review/$id.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    if (c['before'] == null || c['after'] == null) {
      results.add({'id': id, 'status': 'failed', 'error': c['error']});
      continue;
    }
    final texts = (c['text'] as List).cast<String>();
    final spans = <String, ({int start, int end})>{};
    var at = 0;
    for (var i = 0; i < texts.length; i++) {
      spans['sentence-$i'] = (start: at, end: at + texts[i].length);
      at += texts[i].length;
    }
    List<RolePrediction> labels(Map state) {
      final cast = {
        for (final c in state['characters'] as List)
          c['id']: c['name'] as String,
      };
      final raw = {for (final a in state['labels'] as List) a['id']: a};
      return [
        for (final entry in spans.entries)
          RolePrediction(
            entry.value.start,
            entry.value.end,
            NovelSegmentKind.values.byName(raw[entry.key]['kind'] as String),
            cast[raw[entry.key]['characterId']],
          ),
      ];
    }

    final roster = (fixture['roster'] as List).cast<Map<String, dynamic>>();
    final gold = (fixture['gold'] as List).cast<Map<String, dynamic>>();
    final before = labels(c['before'] as Map),
        after = labels(c['after'] as Map);
    final session = c['session'] as Map;
    final requests = (capture['requests'] as List)
        .where((r) => r['case'] == id)
        .toList();
    final metrics = RoleReviewEvaluation.compare(
      text: texts.join(),
      gold: gold,
      roster: roster,
      before: before,
      after: after,
      predictedCast: ((c['after'] as Map)['characters'] as List)
          .cast<Map<String, dynamic>>(),
      flagged: [for (final id in session['targets'] as List) spans[id]!],
      // Replicates are deliberately not fabricated from before/after outputs.
    );
    results.add({
      'id': id,
      'status': session['status'],
      'metrics': metrics,
      'before': RoleEvaluation.evaluate(
        text: texts.join(),
        gold: gold,
        predictions: before,
        roster: roster,
      ).toJson(),
      'after': RoleEvaluation.evaluate(
        text: texts.join(),
        gold: gold,
        predictions: after,
        roster: roster,
      ).toJson(),
      'calls': session['calls'],
      'reportedTokens': session['reportedTokens'],
      'chargedTokens': session['chargedTokens'],
      'tokensPerNetCorrection': (metrics['netGain'] as int) > 0
          ? (session['reportedTokens'] as int) / (metrics['netGain'] as int)
          : null,
      'elapsedMs': session['elapsedMs'],
      'requestElapsedMs': requests.fold<int>(
        0,
        (n, r) => n + (r['elapsedMs'] as int? ?? 0),
      ),
      'proposals': (session['proposals'] as List)
          .map((p) => p['action'])
          .toList(),
    });
  }
  final report = {
    'model': capture['model'],
    'calls': capture['calls'],
    'reportedTokens': capture['reportedTokens'],
    'chargedTokens': capture['chargedTokens'],
    'results': results,
  };
  File(
    '${file.parent.path}/report.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  final md = StringBuffer('# P1 局部工具校对实测\n\n')
    ..writeln(
      '模型 ${capture['model']}；${capture['calls']} 次调用，已报告 ${capture['reportedTokens']} tokens；计费预算用量 ${capture['chargedTokens']}（含未知失败预留）。',
    )
    ..writeln(
      '\n测试人为植入错标/漏人/重复身份的短样本；金标未发送给模型。费用用量由 API usage 记录，不换算美元。未重跑 P0 全文推理、未做多轮一致率比较。',
    )
    ..writeln('\n| 样本 | 改对/改坏/净收益 | 人物召回/重复 | 疑点精确率/召回率 | 调用/tokens/秒 |')
    ..writeln('|---|---|---|---|---|');
  for (final r in results) {
    final m = r['metrics'] as Map?;
    if (m == null) {
      md.writeln('| ${r['id']} | failed | — | — | — |');
      continue;
    }
    md.writeln(
      '| ${r['id']} | ${m['corrected']}/${m['harmed']}/${m['netGain']} | ${m['recalledIdentities']}/${m['goldIdentities']}；重复 ${m['duplicateIdentities']} | ${m['doubtPrecision']}/${m['doubtRecall']} | ${r['calls']}/${r['reportedTokens']}/${(r['elapsedMs'] as int) / 1000} |',
    );
  }
  md.writeln(
    '\n疑点指标只在带金标的片段上计算，flagged 为本次显式选择的送审目标，不代表 P0 独立疑点检测器的泛化效果。无分母及未做的多轮一致率为 null。人物名称仅按金标及显式别名匹配，歧义身份另列。',
  );
  md.writeln(
    '\n原始请求、响应、usage、技能指纹、提案、采纳前后标签均在 capture.json。所有采纳只发生在内存测试库，仍为 AI inferred；正文保持不变。两组短样本不能证明全题材准确率或长章节效果。',
  );
  File('${file.parent.path}/report.md').writeAsStringSync('$md');
  stdout.writeln(
    'Wrote ${file.parent.path}/report.md and report.json (offline).',
  );
}
