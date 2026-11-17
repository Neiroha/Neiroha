import 'dart:convert';
import 'dart:io';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';

/// Offline scorer. No credentials or network calls. Predictions are captured
/// separately so test fixtures can never silently substitute for model results.
void main(List<String> args) {
  if (args.length < 2 || args.length > 3) {
    stderr.writeln(
      'Usage: dart scripts/tools/evaluate_role_assignments.dart <predictions-dir> <report.md> [reviewed-identity-map.json]',
    );
    exitCode = 64;
    return;
  }
  final identityMap = args.length == 3
      ? jsonDecode(File(args[2]).readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final fixtures =
      Directory('scripts/tests/fixtures/role_assign')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final rows = <String>[];
  final results = <String, Object?>{};
  final identities = <String, Object?>{};
  final models = <String>{};
  final inferenceSkills = <String>{};
  var missing = 0,
      evaluated = 0,
      kinds = 0,
      speakerTotal = 0,
      speakers = 0,
      ambiguous = 0;
  String rate(int hits, int total) => total == 0
      ? 'n/a'
      : '${(100 * hits / total).toStringAsFixed(1)}% ($hits/$total)';
  for (final file in fixtures) {
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = fixture['id'] as String;
    final prediction = File('${args[0]}/$id.json');
    if (!prediction.existsSync()) {
      missing++;
      rows.add('| $id | 未运行 | — | — |');
      continue;
    }
    final data =
        jsonDecode(prediction.readAsStringSync()) as Map<String, dynamic>;
    final skill = data['skill'];
    models.add(data['model'] as String? ?? '未记录');
    inferenceSkills.add(
      skill is Map && skill['sha256'] is String
          ? '${skill['name']}@${skill['version']}#${skill['sha256']}'
          : 'legacy/unversioned（推理时未记录 skill 指纹）',
    );
    identities[id] = {
      'model': data['model'],
      'inferenceSkill': skill ?? {'status': 'legacy-unversioned'},
      'processingSkill': data['processingSkill'],
      'sourceRevision': data['sourceRevision'],
    };
    final text = fixture['text'] as String;
    if (data['sourceRevision'] != novelTextRevision(text)) {
      throw FormatException('Source revision mismatch: $id');
    }
    final roster = (fixture['roster'] as List)
        .cast<Map<String, dynamic>>()
        .map((c) => Map<String, dynamic>.of(c))
        .toList();
    final mappings = identityMap[id] as Map<String, dynamic>? ?? {};
    for (final entry in mappings.entries) {
      // Some upstream gold alternatives use the explicit unknown-role label
      // without adding it to the cast. Keep that uncertainty when aligning names.
      if (!roster.any((c) => c['name'] == entry.value)) {
        final allowed = (fixture['gold'] as List).any(
          (g) =>
              g['speaker'] == entry.value ||
              (g['speaker'] is List &&
                  (g['speaker'] as List).contains(entry.value)),
        );
        if (allowed) roster.add({'name': entry.value, 'aliases': <String>[]});
      }
      final target = roster.where((c) => c['name'] == entry.value).toList();
      final present = (data['labels'] as List).any(
        (p) => p['speaker'] == entry.key,
      );
      if (target.length != 1 ||
          !present ||
          roster.any(
            (c) =>
                c['name'] != entry.value &&
                (c['name'] == entry.key ||
                    ((c['aliases'] as List?)?.contains(entry.key) ?? false)),
          )) {
        throw FormatException(
          'Invalid or ambiguous reviewed identity mapping: $id/${entry.key}',
        );
      }
      target.single['aliases'] = [
        ...?target.single['aliases'] as List?,
        entry.key,
      ];
    }
    final result = RoleEvaluation.evaluate(
      text: text,
      gold: (fixture['gold'] as List).cast<Map<String, dynamic>>(),
      roster: roster,
      predictions: (data['labels'] as List)
          .map((p) => RolePrediction.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
    evaluated += result.evaluated;
    kinds += result.categoryCorrect;
    speakerTotal += result.speakerTotal;
    speakers += result.speakerCorrect;
    ambiguous += result.ambiguousGold;
    results[id] = result.toJson();
    rows.add(
      '| $id | ${rate(result.categoryCorrect, result.evaluated)} | ${rate(result.speakerCorrect, result.speakerTotal)} | ${result.ambiguousGold} |',
    );
  }
  final report = File(args[1]);
  report.parent.createSync(recursive: true);
  report.writeAsStringSync(
    '# 分角效果评测\n\n'
    '离线核对已提供的模型输出；缺失输出不计为通过。UTF-16 标签必须完整覆盖原文，歧义金标单列排除。\n\n'
    '模型：${models.join('、')}。\n\n推理 skill：${inferenceSkills.join('；')}。回放处理版本单列于 metadata.json，不替代推理版本。\n\n'
    '${args.length == 3 ? '已应用人工复核的身份名称对应表：`${args[2]}`；未修改类别、人物归属或金标。\n\n' : '人物仅按金标姓名及其原有别名进行严格匹配。\n\n'}'
    '类别：${rate(kinds, evaluated)}；人物：${rate(speakers, speakerTotal)}；歧义金标：$ambiguous；未运行：$missing。\n\n'
    '| 用例 | 类别正确率 | 人物正确率 | 歧义金标 |\n|---|---|---|---|\n${rows.join('\n')}\n',
  );
  File(
    '${args[1]}.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  File(
    '${args[1]}.metadata.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(identities));
  stdout.writeln(
    'Scored ${fixtures.length - missing}/${fixtures.length} cases; $missing missing. Report: ${report.path}',
  );
  if (missing > 0) exitCode = 2;
}
