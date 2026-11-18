import 'dart:convert';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

class FakeStructuredLlm extends LlmChatAdapter {
  FakeStructuredLlm(this.reply)
    : super(baseUrl: 'http://localhost', apiKey: '', modelName: 'fake');
  final Future<Map<String, dynamic>> Function(
    String stage,
    Map<String, dynamic> input,
    TtsCancelToken cancellation,
  )
  reply;
  @override
  Future<LlmStructuredResult> structured({
    required List<LlmChatMessage> messages,
    required String schemaName,
    required Map<String, Object?> schema,
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async => LlmStructuredResult(
    await reply(
      schemaName,
      jsonDecode(messages.last.content) as Map<String, dynamic>,
      cancellation,
    ),
    finishReason: 'stop',
  );
}
