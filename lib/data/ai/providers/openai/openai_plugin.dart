import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_catalog.dart';
import 'package:neiroha/data/ai/providers/openai/openai_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

class OpenAiPlugin extends ProviderPlugin {
  const OpenAiPlugin();
  @override
  String get id => 'openai';
  @override
  String get displayName => 'OpenAI';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.llm,
    AiCapability.tts,
    AiCapability.stt,
    AiCapability.realtime,
    AiCapability.translate,
  };
  @override
  List<ModelDescriptor> get catalog => openAiCatalog;
  @override
  ProviderConnection connect(ConnectionConfig config) =>
      OpenAiConnection(this, config);
}
