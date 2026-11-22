import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'mimo_catalog.dart';
import 'mimo_connection.dart';

/// Xiaomi MiMo: chat-completions TTS, MiMo text models and `mimo-v2.5-asr`.
/// All use the OpenAI Chat Completions protocol with an `api-key` header.
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
    AiCapability.stt,
  };
  @override
  List<ModelDescriptor> get catalog => [
    ttsDescriptor,
    ...mimoLlmCatalog,
    mimoAsrDescriptor,
  ];

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      MiMoConnection(this, config);
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
