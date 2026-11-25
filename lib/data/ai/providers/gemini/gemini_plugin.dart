import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/providers/common/adapter_tts_plugin.dart';
import 'package:neiroha/domain/ai/capability.dart';
import 'package:neiroha/domain/ai/llm_traits.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'gemini_catalog.dart';
import 'gemini_connection.dart';

/// Google AI Studio: one key for native TTS, Gemini text models (native
/// generateContent), transcription and Live (realtime voice, streaming
/// transcription, speech translation) and Lyria song generation.
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
    AiCapability.stt,
    AiCapability.realtime,
    AiCapability.translate,
    AiCapability.music,
  };
  @override
  List<ModelDescriptor> get catalog => [ttsDescriptor, ...geminiCatalog];
  @override
  Map<String, ReasoningEffort> get reasoningDefaults => geminiReasoningDefaults;

  @override
  ProviderConnection connect(ConnectionConfig config) =>
      GeminiConnection(this, config);
}
