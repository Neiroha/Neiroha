import 'dart:async';

import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/data/ai/providers/on_device/vad/energy_vad.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

/// Built-in engines that need no account. Silero (sherpa-onnx) joins in M5;
/// until then an energy detector covers silence trimming and splitting.
class OnDevicePlugin extends ProviderPlugin {
  const OnDevicePlugin();
  static const connectionId = 'on-device';
  @override
  String get id => 'on-device';
  @override
  String get displayName => 'On-device';
  @override
  Set<AiCapability> get capabilities => const {AiCapability.vad};
  @override
  List<ModelDescriptor> get catalog => const [
    ModelDescriptor(
      id: 'energy-vad',
      capability: AiCapability.vad,
      protocol: AiProtocol.onDevice,
      displayName: 'Energy VAD',
      features: {AiFeature.local},
      isDefault: true,
    ),
  ];
  @override
  ProviderConnection connect(ConnectionConfig config) =>
      OnDeviceConnection(this, config);

  static ProviderConnection builtIn() => const OnDevicePlugin().connect(
    const ConnectionConfig(id: connectionId, baseUrl: '', name: 'On-device'),
  );
}

class OnDeviceConnection extends ProviderConnection {
  OnDeviceConnection(super.plugin, super.config);
  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    return descriptor?.source == DescriptorSource.catalog
        ? EnergyVad(descriptor!)
        : null;
  }

  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async => {
    AiCapability.vad: const CapabilityHealth(
      HealthState.ok,
      models: ['energy-vad'],
    ),
  };
}
