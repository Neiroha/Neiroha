import 'package:neiroha/data/ai/providers/common/chat_model.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

/// MiniMax text models on the OpenAI-compatible `/v1/chat/completions`
/// (catalog snapshot 2026-11-17; structured output not yet verified).
final List<ModelDescriptor> miniMaxLlmCatalog = [
  chatModel('MiniMax-M3', isDefault: true),
  chatModel('MiniMax-M3.1-Flash'),
  chatModel('MiniMax-M2.5'),
];
