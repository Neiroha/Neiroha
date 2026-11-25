import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

/// An LLM served over the OpenAI Chat Completions protocol on a vendor's own
/// text endpoint (Gemini, MiniMax, MiMo, gateways).
ModelDescriptor chatModel(
  String id, {
  bool isDefault = false,
  Set<String> features = const {},
  String? shutdownAt,
}) => ModelDescriptor(
  id: id,
  capability: AiCapability.llm,
  protocol: AiProtocol.openAiChat,
  features: features,
  lifecycle: shutdownAt == null ? ModelLifecycle.ga : ModelLifecycle.deprecated,
  shutdownAt: shutdownAt,
  isDefault: isDefault,
);
