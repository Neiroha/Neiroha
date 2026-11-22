import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_connection.dart';
import 'package:neiroha/data/ai/providers/legacy/legacy_options.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// One existing adapter type as a plugin: TTS, plus LLM where the provider
/// also serves role AI.
class LegacyTtsPlugin extends ProviderPlugin {
  const LegacyTtsPlugin(this.type);
  final AdapterType type;

  @override
  String get id => type.name;
  @override
  String get displayName => type.displayName;

  bool get servesLlm =>
      rowFor(const ConnectionConfig(id: '', baseUrl: '')).supportsRoleAi;

  @override
  Set<AiCapability> get capabilities => {
    AiCapability.tts,
    if (servesLlm) AiCapability.llm,
  };

  @override
  List<ModelDescriptor> get catalog => [
    ModelDescriptor(
      id: type.defaultModel.isEmpty ? 'default' : type.defaultModel,
      capability: AiCapability.tts,
      protocol: AiProtocol.native,
      features: {
        if (type.supportsVoiceQuery) AiFeature.presetVoices,
        if (type.supportsCloudVoiceClone) AiFeature.cloudClone,
        if (type.requiresReferenceAudio) AiFeature.zeroShotClone,
      },
      platforms: type == AdapterType.systemTts
          ? const {AiPlatform.desktop}
          : allPlatforms,
      isDefault: true,
    ),
  ];

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      LegacyConnection(this, config);

  db.TtsProvider rowFor(ConnectionConfig config) => db.TtsProvider(
    id: config.id,
    name: config.name.isEmpty ? type.displayName : config.name,
    adapterType: type.name,
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    defaultModelName:
        config.options[LegacyOptions.defaultModel] ?? type.defaultModel,
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );
}
