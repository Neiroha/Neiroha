import 'package:neiroha/data/ai/providers/common/chat_model.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

const _structured = {AiFeature.structuredOutput};

/// Xiaomi MiMo text models (catalog snapshot 2026-11-17).
final List<ModelDescriptor> mimoLlmCatalog = [
  chatModel('mimo-v2.6-pro', isDefault: true, features: _structured),
  chatModel('mimo-v2.6-flash', features: _structured),
];

/// Speech recognition over Chat Completions (`input_audio` part). Listed by
/// `GET models` on 2026-11-22; the request shape follows the OpenAI audio
/// input convention MiMo's chat API speaks.
const mimoAsrDescriptor = ModelDescriptor(
  id: 'mimo-v2.5-asr',
  capability: AiCapability.stt,
  protocol: AiProtocol.openAiChat,
  displayName: 'MiMo V2.5 ASR',
  features: {AiFeature.fileTranscription, AiFeature.keywords},
  isDefault: true,
);
