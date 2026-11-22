import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'gemini_catalog.dart';

/// Google AI Studio: native Gemini TTS plus Gemini text models, one key.
class GeminiPlugin extends AdapterTtsPlugin {
  const GeminiPlugin() : super(AdapterType.geminiTts);
  @override
  String get id => 'gemini';
  @override
  String get displayName => 'Google Gemini';
  @override
  Set<AiCapability> get capabilities => const {
    AiCapability.tts,
    AiCapability.llm,
  };
  @override
  List<ModelDescriptor> get catalog => [ttsDescriptor, ...geminiLlmCatalog];
}
