import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'support/evaluation_budget.dart';

void main() {
  late Directory tmp;
  late EvaluationBudget ledger;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('neiroha-eval-budget-');
    ledger = EvaluationBudget('${tmp.path}/budget.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));
  Map read() => jsonDecode(File(ledger.path).readAsStringSync()) as Map;
  int begin() => ledger.begin(
    'gpt-6-luna',
    'test',
    [const LlmChatMessage(role: 'user', content: '小样本')],
    {},
    1600,
  );
  test(
    'reservation is persistent across instances and failed usage stays charged',
    () {
      final id = begin();
      final reserved = (read()['requests'] as List).single['chargedMicroUsd'];
      ledger.finish(id, null);
      expect((read()['requests'] as List).single['chargedMicroUsd'], reserved);
      final other = EvaluationBudget(ledger.path);
      other.begin('gpt-6-luna', 'test', [], {}, 1600);
      expect(read()['requests'], hasLength(2));
    },
  );
  test(
    'known usage is reconciled once and price estimate keeps cache writes conservative',
    () {
      final id = begin();
      ledger.finish(id, {
        'total_tokens': 1000,
        'prompt_tokens': 800,
        'completion_tokens': 200,
      });
      ledger.finish(id, null);
      final row = (read()['requests'] as List).single;
      expect(row['chargedMicroUsd'], 2000);
      expect(row['standardPriceUpperMicroUsd'], 200);
      expect(row['status'], 'completed');
    },
  );
  test(
    'the shared ledger can continue past 1200 attempts within its dollar limit',
    () {
      begin();
      final data = read();
      data['requests'] = List.generate(
        1200,
        (id) => {'id': id, 'chargedMicroUsd': 2000},
      );
      File(ledger.path).writeAsStringSync(jsonEncode(data));
      expect(begin(), 1200);
      expect(read()['requests'], hasLength(1201));
    },
  );
  test(
    'limit and authorization failures refuse subsequent calls before send',
    () {
      final id = begin();
      ledger.finish(id, null, statusCode: 401);
      expect(begin, throwsStateError);
      final data = read()..remove('blockedReason');
      data['limitMicroUsd'] = 1;
      File(ledger.path).writeAsStringSync(jsonEncode(data));
      expect(begin, throwsStateError);
      expect(read()['requests'], hasLength(1));
      data['limitMicroUsd'] = 50000001;
      File(ledger.path).writeAsStringSync(jsonEncode(data));
      expect(begin, throwsStateError);
      expect(
        () => ledger.begin('expensive-model', 'test', [], {}, 1600),
        throwsStateError,
      );
    },
  );
}
