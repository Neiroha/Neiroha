import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'evaluation_budget.dart';
import 'evaluation_proxy.dart';

class BudgetedEvaluationLlm extends LlmChatAdapter {
  BudgetedEvaluationLlm(String key, this.budget, this.record)
    : super(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: key,
        modelName: 'gpt-6-luna',
        httpClientAdapter: evaluationProxy(),
      );
  final EvaluationBudget budget;
  final void Function(Map<String, Object?>) record;
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
    final receipt = budget.begin(
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
        allowFormatFallback: false,
        timeout: timeout,
      );
      budget.finish(receipt, result.usage);
      record({
        'receipt': receipt,
        'stage': schemaName,
        'usage': result.usage,
        'elapsedMs': watch.elapsedMilliseconds,
        'input': messages.map((m) => m.toJson()).toList(),
        'output': result.object,
        'finishReason': result.finishReason,
      });
      return result;
    } catch (error) {
      budget.finish(
        receipt,
        null,
        statusCode: error is LlmChatException ? error.statusCode : null,
      );
      record({
        'receipt': receipt,
        'stage': schemaName,
        'elapsedMs': watch.elapsedMilliseconds,
        'error': '$error'.replaceAll(apiKey, '[REDACTED]'),
      });
      rethrow;
    }
  }
}
