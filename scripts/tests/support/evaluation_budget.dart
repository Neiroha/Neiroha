import 'dart:convert';
import 'dart:io';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';

/// Process-safe, shared paid-evaluation ledger. Unknown usage is never refunded.
/// 2 USD / million total tokens is a conservative guard for Luna standard text
/// pricing verified on 2026-11-17; it is not the provider invoice.
class EvaluationBudget {
  EvaluationBudget(this.path);
  final String path;
  static EvaluationBudget? fromEnvironment() {
    final path = Platform.environment['NEIROHA_EVAL_BUDGET_FILE'];
    return path == null || path.isEmpty ? null : EvaluationBudget(path);
  }

  T _edit<T>(T Function(Map<String, dynamic>) action) {
    final file = File(path)..parent.createSync(recursive: true);
    final lock = File('$path.lock').openSync(mode: FileMode.append);
    lock.lockSync(FileLock.blockingExclusive);
    try {
      final data = file.existsSync()
          ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
          : <String, dynamic>{
              'version': 1,
              'limitMicroUsd': 50000000,
              'model': 'gpt-6-luna',
              'requests': <dynamic>[],
            };
      final result = action(data);
      final tmp = File('$path.tmp');
      tmp.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
      tmp.renameSync(path);
      return result;
    } finally {
      lock.unlockSync();
      lock.closeSync();
    }
  }

  int begin(
    String model,
    String stage,
    List<LlmChatMessage> messages,
    Map<String, Object?> schema,
    int maxOutput,
  ) => _edit((data) {
    if (model != 'gpt-6-luna' ||
        data['model'] != model ||
        data['blockedReason'] != null) {
      throw StateError(
        'The paid quality run requires gpt-6-luna and an unblocked ledger.',
      );
    }
    final input = utf8
        .encode(jsonEncode(messages.map((m) => m.toJson()).toList()))
        .length;
    final reserve =
        input + utf8.encode(jsonEncode(schema)).length + maxOutput + 512;
    final entries = data['requests'] as List;
    final limit = data['limitMicroUsd'];
    if (limit is! int || limit < 1 || limit > 50000000) {
      throw StateError('The shared evaluation limit must not exceed USD 50.');
    }
    final spent = entries.fold<int>(
      0,
      (n, e) => n + (e['chargedMicroUsd'] as int),
    );
    if (spent + reserve * 2 > limit) {
      throw StateError(
        'Shared USD 50 evaluation budget exhausted; no request sent.',
      );
    }
    entries.add({
      'id': entries.length,
      'stage': stage,
      'status': 'inFlight',
      'outputLimit': maxOutput,
      'inputBytes': input,
      'reservedTokens': reserve,
      'chargedMicroUsd': reserve * 2,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    });
    return entries.length - 1;
  });
  void finish(
    int id,
    Map<String, dynamic>? usage, {
    int? statusCode,
  }) => _edit<void>((data) {
    final entry = (data['requests'] as List)[id] as Map;
    if (entry['status'] == 'completed') return;
    final total = usage?['total_tokens'];
    entry['status'] = usage == null ? 'failedUnknownUsage' : 'completed';
    if (usage != null) entry['usage'] = usage;
    if (total is int && total > 0) {
      entry['chargedMicroUsd'] = total * 2;
      final input = usage?['prompt_tokens'],
          output = usage?['completion_tokens'];
      if (input is int && output is int) {
        // Price all input at the higher cache-write rate; do not assume discounts.
        entry['standardPriceUpperMicroUsd'] = (input * .125 + output * .5)
            .ceil();
      }
    }
    entry['finishedAt'] = DateTime.now().toUtc().toIso8601String();
    if ([401, 403, 429].contains(statusCode)) {
      data['blockedReason'] =
          'Provider authorization/rate failure ($statusCode).';
    }
  });
}
