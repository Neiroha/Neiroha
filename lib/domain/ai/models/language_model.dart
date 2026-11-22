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
