import 'dart:async';

import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

abstract interface class LanguageModel implements CapabilityModel {
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens,
  });

  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens,
  });
}

/// A language model that hands out its answer as it is generated, so speech
/// can start on the first sentence instead of the last token.
abstract interface class StreamingLanguageModel implements LanguageModel {
  /// Text deltas of the answer, in order; thoughts are never included.
  Stream<String> streamText(
    List<LlmChatMessage> messages, {
    required TtsCancelToken cancellation,
    int maxOutputTokens,
  });
}

/// [model]'s answer as deltas: streamed when the model supports it, else the
/// whole completion as one delta.
Stream<String> streamCompletion(
  LanguageModel model,
  List<LlmChatMessage> messages, {
  required TtsCancelToken cancellation,
  int maxOutputTokens = 4096,
}) async* {
  if (model is StreamingLanguageModel) {
    yield* model.streamText(
      messages,
      cancellation: cancellation,
      maxOutputTokens: maxOutputTokens,
    );
    return;
  }
  yield await model.complete(
    messages,
    cancellation: cancellation,
    maxOutputTokens: maxOutputTokens,
  );
}
