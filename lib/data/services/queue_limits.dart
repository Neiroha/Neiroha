import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';

/// The limits one queue lane runs under: a connection's own columns, with
/// its `connection_capabilities` row (if any) taking precedence per field.
class QueueLimits {
  const QueueLimits({
    this.maxConcurrency = 1,
    this.requestsPerMinute,
    this.requestsPerDay,
    this.tokensPerMinute,
    this.tokensPerDay,
  });

  factory QueueLimits.of(db.TtsProvider p, [db.ConnectionCapability? row]) =>
      QueueLimits(
        maxConcurrency: (row?.maxConcurrency ?? p.maxConcurrency)
            .clamp(1, 64)
            .toInt(),
        requestsPerMinute: row?.requestsPerMinute ?? p.requestsPerMinute,
        requestsPerDay: row?.requestsPerDay ?? p.requestsPerDay,
        tokensPerMinute: row?.tokensPerMinute ?? p.tokensPerMinute,
        tokensPerDay: row?.tokensPerDay ?? p.tokensPerDay,
      );

  final int maxConcurrency;
  final int? requestsPerMinute;
  final int? requestsPerDay;
  final int? tokensPerMinute;
  final int? tokensPerDay;
}

/// One lane per connection × capability, so the LLM calls of a connection
/// queue apart from (and do not use up) its TTS slots.
String queueLane(String connectionId, AiCapability capability) =>
    capability == AiCapability.tts
    ? connectionId
    : '$connectionId|${capability.name}';
