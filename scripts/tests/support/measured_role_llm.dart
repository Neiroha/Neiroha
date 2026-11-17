import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'evaluation_budget.dart';
import 'evaluation_proxy.dart';

class MeasuredRoleLlm extends LlmChatAdapter {
  MeasuredRoleLlm(
    String key,
    String model,
    this.record,
    this.before, {
    this.replay,
    this.paidPrefix = const [],
  }) : super(
         baseUrl: 'https://api.openai.com/v1',
         apiKey: key,
         modelName: model,
         httpClientAdapter: evaluationProxy(),
       );
  final void Function(Map<String, Object?>) record;
  final void Function() before;
  final List<dynamic>? replay;
  final List<dynamic> paidPrefix;
  int replayIndex = 0;
  int prefixIndex = 0;
  void verifyReplayComplete() {
    if (replay != null && replayIndex != replay!.length) {
      throw StateError('Replay did not consume the captured request sequence.');
    }
    if (prefixIndex != paidPrefix.length) {
      throw StateError('Saved prefix was not fully consumed.');
    }
  }

  @override
  Future<LlmStructuredResult> structured({
    required List<LlmChatMessage> messages,
    required String schemaName,
    required Map<String, Object?> schema,
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    // Explicit offline mode: incomplete captures fail without network fallback.
    if (replay != null || prefixIndex < paidPrefix.length) {
      if (replay != null && replayIndex >= replay!.length) {
        throw StateError('Incomplete capture.');
      }
      final entry =
          (replay != null ? replay![replayIndex++] : paidPrefix[prefixIndex++])
              as Map<String, dynamic>;
      if (entry['stage'] != schemaName) {
        throw StateError('Capture stage mismatch.');
      }
      record({...entry, 'replayed': true});
      return LlmStructuredResult(
        entry['output'] as Map<String, dynamic>,
        finishReason: entry['finishReason'] as String,
        responseFormat: entry['format'] as String,
        usage: entry['usage'] as Map<String, dynamic>,
      );
    }
    before();
    final budget = EvaluationBudget.fromEnvironment();
    final receipt = budget?.begin(
      modelName,
      schemaName,
      messages,
      schema,
      maxOutputTokens,
    );
    final watch = Stopwatch()..start();
    try {
      final result = await super.structured(
        messages: messages,
        schemaName: schemaName,
        schema: schema,
        cancellation: cancellation,
        maxOutputTokens: maxOutputTokens,
        allowFormatFallback: budget == null && allowFormatFallback,
        timeout: timeout,
      );
      if (receipt != null) budget!.finish(receipt, result.usage);
      record({
        'budgetReceipt': receipt,
        'stage': schemaName,
        'elapsedMs': watch.elapsedMilliseconds,
        'usage': result.usage,
        'format': result.responseFormat,
        'finishReason': result.finishReason,
        'output': result.object,
      });
      return result;
    } catch (error) {
      if (receipt != null) {
        budget!.finish(
          receipt,
          null,
          statusCode: error is LlmChatException ? error.statusCode : null,
        );
      }
      record({
        'budgetReceipt': receipt,
        'stage': schemaName,
        'status': 'failed',
        'elapsedMs': watch.elapsedMilliseconds,
        'error': '$error'.replaceAll(
          apiKey,
          apiKey.isEmpty ? '' : '[REDACTED]',
        ),
      });
      rethrow;
    }
  }
}
