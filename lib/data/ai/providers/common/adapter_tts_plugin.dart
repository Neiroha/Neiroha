import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'adapter_backed_connection.dart';

/// Option keys a `TtsProviders` row contributes to [ConnectionConfig].
abstract final class AdapterOptions {
  static const adapterType = 'adapterType';
  static const defaultModel = 'defaultModel';
}

/// A vendor whose TTS speaks its own wire protocol through an existing
/// `TtsAdapter`. Used as-is for TTS-only engines (Azure, system TTS, local
/// GPT-SoVITS / CosyVoice / IndexTTS / VoxCPM2); vendor plugins extend it to
/// add LLM, STT or VC.
class AdapterTtsPlugin extends ProviderPlugin {
  const AdapterTtsPlugin(this.type);
  final AdapterType type;

  @override
  String get id => type.name;
  @override
  String get displayName => type.displayName;
  @override
  Set<AiCapability> get capabilities => const {AiCapability.tts};

  /// The adapter's default TTS model, with badges from the adapter type.
  ModelDescriptor get ttsDescriptor => ModelDescriptor(
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
  );

  @override
  List<ModelDescriptor> get catalog => [ttsDescriptor];

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      AdapterBackedConnection(this, config);

  /// The row `createAdapter` and role-AI routing expect.
  db.TtsProvider rowFor(ConnectionConfig config) => db.TtsProvider(
    id: config.id,
    name: config.name.isEmpty ? type.displayName : config.name,
    adapterType: type.name,
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    defaultModelName:
        config.options[AdapterOptions.defaultModel] ?? type.defaultModel,
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );
}
