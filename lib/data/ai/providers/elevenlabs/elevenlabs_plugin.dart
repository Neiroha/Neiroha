import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/elevenlabs_connection.dart';
import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// ElevenLabs: TTS (existing adapter), Scribe STT and speech-to-speech VC
/// under one `xi-api-key`.
class ElevenLabsPlugin extends AdapterTtsPlugin {
  const ElevenLabsPlugin() : super(AdapterType.elevenLabs);
  @override
  String get id => 'elevenlabs';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.stt,
    AiCapability.vc,
  };
  @override
  List<ModelDescriptor> get catalog => [
    ...super.catalog,
    const ModelDescriptor(
      id: 'scribe_v2',
      capability: AiCapability.stt,
      protocol: AiProtocol.elevenLabs,
      features: {
        AiFeature.fileTranscription,
        AiFeature.wordTimestamps,
        AiFeature.diarization,
        AiFeature.languageDetection,
      },
      isDefault: true,
    ),
    const ModelDescriptor(
      id: 'eleven_multilingual_sts_v2',
      capability: AiCapability.vc,
      protocol: AiProtocol.elevenLabs,
      features: {AiFeature.zeroShot},
      isDefault: true,
    ),
  ];
  @override
  ProviderConnection connect(ConnectionConfig config) =>
      ElevenLabsConnection(this, config);
}
