import 'dart:convert';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';

/// Shared across cases. Reserve before network and retain unknown failed usage.
class ReviewLiveLedger {
  int calls = 0, charged = 0, reported = 0;
  final requests = <Map<String, Object?>>[];
  bool failed = false;
}

class ReviewLiveClient extends LlmChatAdapter {
  ReviewLiveClient(
    String key,
    String model,
    this.caseId,
    this.ledger,
    this.save,
  ) : super(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: key,
        modelName: model,
      );
  final String caseId;
  final ReviewLiveLedger ledger;
  final void Function() save;
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
    final reserve =
        utf8
            .encode(jsonEncode(messages.map((m) => m.toJson()).toList()))
            .length +
        utf8.encode(jsonEncode(schema)).length +
        maxOutputTokens +
        512;
    if (ledger.failed ||
        ledger.calls >= 6 ||
        ledger.charged + reserve > 40000) {
      throw StateError(
        'Global paid review budget exhausted or previous request failed.',
      );
    }
    ledger.calls++;
    ledger.charged += reserve;
    final entry = <String, Object?>{
      'case': caseId,
      'call': ledger.calls,
      'reservedTokens': reserve,
      'outputLimit': maxOutputTokens,
      'status': 'inFlight',
      'input': messages.map((m) => m.toJson()).toList(),
    };
    ledger.requests.add(entry);
    save();
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
      final used = result.usage['total_tokens'];
      if (used is int && used > 0) {
        ledger.charged += used - reserve;
        ledger.reported += used;
      }
      entry.addAll({
        'status': 'success',
        'usage': result.usage,
        'object': result.object,
        'finishReason': result.finishReason,
      });
      return result;
    } catch (error) {
      ledger.failed = true;
      entry.addAll({'status': 'failed', 'error': '$error'});
      rethrow;
    } finally {
      entry['elapsedMs'] = watch.elapsedMilliseconds;
      save();
    }
  }
}
