import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_client.dart';
import 'package:neiroha/data/ai/providers/local/rvc/vc/rvc_voice_converter.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// Local Neiroha-RVC server: voice conversion only. Checkpoints and voices
/// are whatever the server has loaded, so they are discovered live.
class RvcPlugin extends ProviderPlugin {
  const RvcPlugin();
  @override
  String get id => AdapterType.rvc.name;
  @override
  String get displayName => AdapterType.rvc.displayName;
  @override
  Set<AiCapability> get capabilities => const {AiCapability.vc};

  /// Works without a listing: the server picks the voice's own checkpoint.
  static const auto = ModelDescriptor(
    id: RvcClient.autoModel,
    capability: AiCapability.vc,
    protocol: AiProtocol.native,
    displayName: 'Auto (by voice)',
    features: {AiFeature.presetVoices},
    isDefault: true,
  );

  @override
  List<ModelDescriptor> get catalog => const [auto];

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      RvcConnection(this, config);
}

class RvcConnection extends ProviderConnection implements LiveModelDiscovery {
  RvcConnection(super.plugin, super.config);

  RvcClient get client =>
      RvcClient(baseUrl: config.baseUrl, apiKey: config.apiKey);

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) =>
      cap == AiCapability.vc ? AiProtocol.native : null;

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    if (descriptor == null || cap != AiCapability.vc) return null;
    return RvcVoiceConverter(descriptor, client);
  }

  @override
  Future<List<ModelDescriptor>> listModels(AiCapability cap) async {
    if (cap != AiCapability.vc) return const [];
    return [
      for (final m in (await client.catalog()).models)
        if (m.available)
          ModelDescriptor(
            id: m.id,
            capability: AiCapability.vc,
            protocol: AiProtocol.native,
            displayName: m.name,
            features: const {AiFeature.presetVoices},
            source: DescriptorSource.provider,
          ),
    ];
  }

  @override
  Future<List<VoiceOption>> listVoices(
    AiCapability cap, {
    String? modelId,
  }) async {
    if (cap != AiCapability.vc) return const [];
    final model = modelId == RvcClient.autoModel ? null : modelId;
    return [
      for (final v in (await client.catalog()).voicesFor(model))
        (id: v.id, name: v.name.isEmpty ? v.id : v.name),
    ];
  }

  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async {
    final c = client;
    if (!await c.health()) {
      return {
        AiCapability.vc: const CapabilityHealth(
          HealthState.failed,
          message: 'Neiroha-RVC is not reachable.',
        ),
      };
    }
    try {
      final catalog = await c.catalog();
      return {
        AiCapability.vc: CapabilityHealth(
          HealthState.ok,
          models: [for (final m in catalog.models) m.id],
        ),
      };
    } catch (error) {
      return {
        AiCapability.vc: CapabilityHealth(HealthState.ok, message: '$error'),
      };
    }
  }
}
