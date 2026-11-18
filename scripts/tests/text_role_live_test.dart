import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/novel/text_role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'support/role_review_fixture.dart';
import 'support/role_skill_fixture.dart';
import 'support/evaluation_budget.dart';
import 'support/budgeted_evaluation_llm.dart';
import '../tools/run_live_tests.dart' show redactCredentials;

void main() {
  final enabled = Platform.environment['NEIROHA_TEXT_ROLE_LIVE'] == '1';
  final key = Platform.environment['OPENAI_TEST_API_KEY'] ?? '';
  final filter = (Platform.environment['OPENAI_ROLE_CASES'] ?? '')
      .split(',')
      .where((s) => s.isNotEmpty)
      .toSet();
  final output = Directory(
    Platform.environment['OPENAI_ROLE_OUT_DIR'] ?? '.dart_tool/text-role-live',
  );
  const story =
      '陈叔正给唐禾讲往事。陈叔说：“那年周柏对我说：『别回头，先上岸。』我听完就照办了。”\n唐禾问：“后来呢？”\n陈叔答：“后来我们都平安回来了。”';
  final cases = [
    {
      'id': 'storyteller',
      'text': story,
      'intent': '按现场访谈实际发言者朗读。陈叔讲故事及其中的引用全部由陈叔读，不给故事内引用另分演员；唐禾的提问单独分声线。',
      'gold': [
        {'match': '别回头，先上岸。', 'category': 'dialogue', 'speaker': '陈叔'},
        {'match': '后来呢？', 'category': 'dialogue', 'speaker': '唐禾'},
      ],
      'roster': [
        {'name': '陈叔'},
        {'name': '唐禾'},
        {'name': '周柏'},
      ],
    },
    {
      'id': 'dramatized',
      'text': story,
      'intent': '广播剧演绎。陈叔是外层讲述者；明确归给周柏的嵌套直接引语要由周柏的声线读，引语结束后回到陈叔。不得改写原文。',
      'gold': [
        {'match': '别回头，先上岸。', 'category': 'dialogue', 'speaker': '周柏'},
        {'match': '后来呢？', 'category': 'dialogue', 'speaker': '唐禾'},
      ],
      'roster': [
        {'name': '陈叔'},
        {'name': '唐禾'},
        {'name': '周柏'},
      ],
    },
    {
      'id': 'screenplay',
      'text': '唐禾：欢迎回来，许宁。\n（许宁放下背包，林舟调暗灯光但没有说话。）\n许宁：我把航海日记带来了。\n唐禾：请开始吧。',
      'intent': '保留台本原文。舞台说明作旁白；人物前缀后的台词归前缀人物，不能把灯光师的动作当发言。',
      'gold': [
        {'match': '欢迎回来，许宁。', 'category': 'dialogue', 'speaker': '唐禾'},
        {'match': '我把航海日记带来了。', 'category': 'dialogue', 'speaker': '许宁'},
        {'match': '林舟调暗灯光但没有说话', 'category': 'narrator'},
      ],
      'roster': [
        {'name': '唐禾'},
        {'name': '许宁'},
      ],
    },
  ];
  for (final c in cases) {
    test(
      'real shared text roles and user intent: ${c['id']}',
      () async {
        expect(key, isNotEmpty);
        final ledger = EvaluationBudget.fromEnvironment();
        expect(
          ledger,
          isNotNull,
          reason: 'This suite requires the shared USD 50 guard.',
        );
        output.createSync(recursive: true);
        final artifact = File('${output.path}/${c['id']}.json');
        expect(
          artifact.existsSync(),
          isFalse,
          reason: 'Preserve captures; choose a fresh directory.',
        );
        final f = RoleReviewFixture();
        await f.init();
        addTearDown(f.close);
        final entries = <Map<String, Object?>>[];
        final capture = <String, Object?>{
          'model': 'gpt-6-luna',
          'id': c['id'],
          'text': c['text'],
          'intent': c['intent'],
          'skill': (await loadTestRoleSkill()).identity,
          'requests': entries,
        };
        void save() => artifact.writeAsStringSync(
          redactCredentials(
            const JsonEncoder.withIndent('  ').convert(capture),
            key,
          ),
        );
        final llm = BudgetedEvaluationLlm(key, ledger!, (e) {
          entries.add(e);
          save();
        });
        try {
          final plan =
              await TextRoleAnalysisService(
                TtsQueueService.instance,
                loadSkill: loadTestRoleSkill,
              ).analyze(
                text: c['text'] as String,
                intent: c['intent'] as String,
                provider: f.provider.copyWith(
                  apiKey: key,
                  baseUrl: 'https://api.openai.com/v1',
                ),
                model: 'gpt-6-luna',
                cancellation: TtsCancelToken(),
                client: llm,
              );
          final names = {for (final p in plan.characters) p.id: p.name};
          final labels = [
            for (final p in plan.units)
              RolePrediction(p.start, p.end, p.kind, names[p.characterId]),
          ];
          final evaluation = RoleEvaluation.evaluate(
            text: plan.text,
            gold: (c['gold'] as List).cast<Map<String, dynamic>>(),
            roster: (c['roster'] as List).cast<Map<String, dynamic>>(),
            predictions: labels,
          );
          capture.addAll({
            'status': 'completed',
            'calls': plan.calls,
            'evaluation': evaluation.toJson(),
            'units': [
              for (final p in plan.units)
                {
                  'text': p.text,
                  'start': p.start,
                  'end': p.end,
                  'speaker': names[p.characterId],
                  'kind': p.kind.name,
                  'review': p.review.name,
                  'reason': p.reason,
                },
            ],
          });
          expect(plan.units.map((u) => u.text).join(), c['text']);
          stdout.writeln(
            '${c['id']}: speaker ${evaluation.speakerCorrect}/${evaluation.speakerTotal}; category ${evaluation.categoryCorrect}/${evaluation.evaluated}; ${plan.calls} calls.',
          );
        } catch (error) {
          capture.addAll({'status': 'failed', 'error': '$error'});
          rethrow;
        } finally {
          save();
        }
      },
      skip: !enabled || (filter.isNotEmpty && !filter.contains(c['id'])),
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }
}
