import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_connection.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_tts_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_endpoint.dart';
import 'package:neiroha/data/ai/providers/openai/openai_model_factory.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// User-supplied OpenAI-shaped gateway (Speaches, vLLM, LiteLLM…). Every
/// capability starts unknown; models are typed in or declared.
class OpenAiCompatiblePlugin extends LegacyTtsPlugin {
  const OpenAiCompatiblePlugin() : super(AdapterType.openaiCompatible);
  @override
  String get id => 'openai-compatible';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.llm,
    AiCapability.stt,
  };
  @override
  ProviderConnection connect(ConnectionConfig config) =>
      OpenAiCompatibleConnection(this, config);
}

class OpenAiCompatibleConnection extends LegacyConnection {
  OpenAiCompatibleConnection(super.plugin, super.config);

  OpenAiEndpoint get _endpoint => OpenAiEndpoint(config.baseUrl, config.apiKey);

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) =>
      cap == AiCapability.stt
      ? AiProtocol.openAiTranscription
      : super.manualProtocol(cap, modelId);

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    if (cap == AiCapability.tts) return super.open(cap, modelId);
    final descriptor = describe(cap, modelId);
    return descriptor == null ? null : openOpenAiModel(descriptor, _endpoint);
  }
}
