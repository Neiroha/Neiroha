import 'package:neiroha/data/ai/providers/common/chat_model.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

const _structured = {AiFeature.structuredOutput};

/// Xiaomi MiMo text models (catalog snapshot 2026-11-17).
final List<ModelDescriptor> mimoLlmCatalog = [
  chatModel('mimo-v2.6-pro', isDefault: true, features: _structured),
  chatModel('mimo-v2.6-flash', features: _structured),
];
