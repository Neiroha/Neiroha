import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/core/provider_plugin.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

import 'on_device_connection.dart';

/// Engines built into the app or the OS. No account; what it offers depends
/// on the platform: VAD everywhere, the OS voice where the OS has one.
/// Silero VAD and offline ASR (sherpa-onnx) join in M5.
class OnDevicePlugin extends ProviderPlugin {
  OnDevicePlugin({PlatformCapabilities? platform})
    : platform = platform ?? PlatformCapabilities.current();
  final PlatformCapabilities platform;

  static const connectionId = 'on-device';
  static const energyVadId = 'energy-vad';
  static const systemTtsId = 'system';

  @override
  String get id => 'on-device';
  @override
  String get displayName => 'On-device';

  bool get hasSystemTts => platform.supportsSystemTtsAdapter;

  @override
  Set<AiCapability> get capabilities => {
    AiCapability.vad,
    if (hasSystemTts) AiCapability.tts,
  };

  @override
  List<ModelDescriptor> get catalog => [
    const ModelDescriptor(
      id: energyVadId,
      capability: AiCapability.vad,
      protocol: AiProtocol.onDevice,
      displayName: 'Energy VAD',
      features: {AiFeature.local},
      isDefault: true,
    ),
    if (hasSystemTts)
      ModelDescriptor(
        id: systemTtsId,
        capability: AiCapability.tts,
        protocol: AiProtocol.onDevice,
        displayName: platform.systemTtsProviderName ?? 'System TTS',
        features: const {AiFeature.presetVoices, AiFeature.local},
        platforms: const {AiPlatform.desktop},
        isDefault: true,
      ),
  ];

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      OnDeviceConnection(this, config);

  /// The always-present connection when no system-TTS row exists.
  static ProviderConnection builtIn({PlatformCapabilities? platform}) =>
      OnDevicePlugin(platform: platform).connect(
        const ConnectionConfig(
          id: connectionId,
          baseUrl: '',
          name: 'On-device',
        ),
      );
}
