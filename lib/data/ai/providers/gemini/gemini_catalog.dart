import 'package:neiroha/data/ai/providers/common/chat_model.dart';
import 'package:neiroha/domain/ai/ai_feature.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

const _structured = {AiFeature.structuredOutput};

/// Gemini text models on the OpenAI-compatible `/v1beta/openai/` endpoint
/// (catalog snapshot 2026-11-17). Transcribe / Live models join in M4 / M6.
final List<ModelDescriptor> geminiLlmCatalog = [
  chatModel('gemini-3.8-flash', isDefault: true, features: _structured),
  chatModel('gemini-4-argon', features: _structured),
  chatModel('gemini-4-carbon', features: _structured),
  chatModel('gemini-4-hydrogen', features: _structured),
  chatModel('gemini-3.5-flash-lite', features: _structured),
  chatModel('gemini-pro-latest', features: _structured),
  chatModel('gemini-flash-latest', features: _structured),
];
