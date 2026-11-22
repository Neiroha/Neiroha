import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/data/ai/providers/openai/stt/openai_chat_transcriber.dart';
import 'package:neiroha/domain/ai/ai.dart';

/// MiMo: native chat-completions TTS, text models, and `mimo-v2.5-asr`
/// (audio in through Chat Completions), all on one `api-key`.
class MiMoConnection extends AdapterBackedConnection {
  MiMoConnection(super.plugin, super.config);

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) =>
      cap == AiCapability.stt
      ? AiProtocol.openAiChat
      : super.manualProtocol(cap, modelId);

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    if (cap != AiCapability.stt) return super.open(cap, modelId);
    final d = describe(cap, modelId);
    return d == null ? null : OpenAiChatTranscriber(d, llmEndpoint);
  }

  /// TTS through the adapter; text and speech recognition from one
  /// `GET models`.
  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async => {
    AiCapability.tts: await checkTts(),
    ...await checkListed({AiCapability.llm, AiCapability.stt}),
  };
}
