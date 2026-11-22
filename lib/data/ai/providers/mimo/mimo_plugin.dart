import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'mimo_catalog.dart';

/// Xiaomi MiMo: chat-completions TTS plus MiMo text models. Both use the
/// OpenAI Chat Completions protocol with an `api-key` header.
class MiMoPlugin extends AdapterTtsPlugin {
  const MiMoPlugin() : super(AdapterType.chatCompletionsTts);
  static const officialHost = 'api.xiaomimimo.com';
  @override
  String get id => 'mimo';
  @override
  String get displayName => 'Xiaomi MiMo';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.llm,
  };
  @override
  List<ModelDescriptor> get catalog => [ttsDescriptor, ...mimoLlmCatalog];
}

/// A non-MiMo host speaking chat-completions TTS: LLM models are typed in.
class ChatCompletionsTtsPlugin extends AdapterTtsPlugin {
  const ChatCompletionsTtsPlugin() : super(AdapterType.chatCompletionsTts);
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.llm,
  };
}
