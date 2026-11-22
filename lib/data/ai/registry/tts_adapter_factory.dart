import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/providers/azure_speech/tts/azure_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/elevenlabs/tts/elevenlabs_adapter.dart';
import 'package:neiroha/data/ai/providers/gemini/tts/gemini_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/local/cosyvoice/tts/cosyvoice_adapter.dart';
import 'package:neiroha/data/ai/providers/local/gpt_sovits/tts/gpt_sovits_adapter.dart';
import 'package:neiroha/data/ai/providers/local/index_tts/tts/index_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/on_device/tts/system_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/local/voxcpm2/tts/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/ai/providers/mimo/tts/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/minimax/tts/minimax_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/openai_compatible/tts/openai_compatible_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/platform/platform_capabilities.dart';

/// Callers that build adapters also need the adapter contract.
export 'package:neiroha/data/ai/core/tts_adapter.dart';

/// Factory to create the correct adapter for a provider.
String ttsAdapterModel(db.TtsProvider provider, String? modelName) =>
    provider.adapterType == 'chatCompletionsTts'
    ? ChatCompletionsTtsAdapter.resolveModel(
        provider.baseUrl,
        provider.defaultModelName,
        modelName,
      )
    : modelName ?? provider.defaultModelName;

bool ttsAdapterSupportsStreaming(db.TtsProvider provider, String? modelName) =>
    switch (provider.adapterType) {
      'openaiTts' || 'azureTts' || 'elevenLabs' || 'minimaxTts' => true,
      'geminiTts' => GeminiTtsAdapter.supportsStreamingModel(
        ttsAdapterModel(provider, modelName),
      ),
      'chatCompletionsTts' => ChatCompletionsTtsAdapter.supportsStreamingModel(
        ttsAdapterModel(provider, modelName),
      ),
      _ => false,
    };

/// [modelName] overrides the provider's default model when provided.
TtsAdapter createAdapter(db.TtsProvider provider, {String? modelName}) {
  final model = ttsAdapterModel(provider, modelName);
  switch (provider.adapterType) {
    case 'openaiCompatible':
      return OpenAiCompatibleAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'openaiTts':
      return OpenAiTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'chatCompletionsTts':
      return ChatCompletionsTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'cosyvoice':
      return CosyVoiceAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'voxcpm2Native':
      return VoxCpm2NativeAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'gptSovits':
      return GptSovitsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'azureTts':
      return AzureTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'systemTts':
      final capabilities = PlatformCapabilities.current();
      if (!capabilities.supportsSystemTtsAdapter) {
        throw UnsupportedError(
          'System TTS is not available on ${capabilities.platformLabel}.',
        );
      }
      return SystemTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'geminiTts':
      return GeminiTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'elevenLabs':
      return ElevenLabsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'minimaxTts':
      return MiniMaxTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    case 'indexTts':
      return IndexTtsAdapter(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        modelName: model,
      );
    default:
      throw UnimplementedError(
        'Adapter not implemented for: ${provider.adapterType}',
      );
  }
}
