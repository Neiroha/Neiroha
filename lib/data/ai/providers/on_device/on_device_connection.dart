import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/common/adapter_speech_synthesizer.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'on_device_plugin.dart';
import 'vad/energy_vad.dart';

class OnDeviceConnection extends ProviderConnection {
  OnDeviceConnection(OnDevicePlugin super.plugin, super.config);

  OnDevicePlugin get onDevice => plugin as OnDevicePlugin;

  /// The OS voice runs through the existing `systemTts` adapter.
  db.TtsProvider get systemTtsRow => db.TtsProvider(
    id: config.id,
    name: config.name.isEmpty ? 'System TTS' : config.name,
    adapterType: AdapterType.systemTts.name,
    baseUrl: config.baseUrl,
    apiKey: '',
    defaultModelName: '',
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final descriptor = describe(cap, modelId);
    if (descriptor == null || descriptor.source != DescriptorSource.catalog) {
      return null;
    }
    return switch (cap) {
      AiCapability.vad => EnergyVad(descriptor),
      AiCapability.tts => AdapterSpeechSynthesizer(
        descriptor,
        createAdapter(systemTtsRow),
      ),
      _ => null,
    };
  }

  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async => {
    AiCapability.vad: const CapabilityHealth(
      HealthState.ok,
      models: [OnDevicePlugin.energyVadId],
    ),
    if (onDevice.hasSystemTts) AiCapability.tts: await _systemTts(),
  };

  Future<CapabilityHealth> _systemTts() async {
    try {
      final ok = await createAdapter(systemTtsRow).healthCheck();
      return CapabilityHealth(
        ok ? HealthState.ok : HealthState.failed,
        models: ok ? const [OnDevicePlugin.systemTtsId] : const [],
      );
    } catch (error) {
      return CapabilityHealth(HealthState.failed, message: '$error');
    }
  }
}
