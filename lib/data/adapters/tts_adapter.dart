import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';
export 'package:neiroha/domain/synthesis/tts_request.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/adapters/openai_compatible_adapter.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/adapters/cosyvoice_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/adapters/gpt_sovits_adapter.dart';
import 'package:neiroha/data/adapters/azure_tts_adapter.dart';
import 'package:neiroha/data/adapters/system_tts_adapter.dart';
import 'package:neiroha/data/adapters/gemini_tts_adapter.dart';
import 'package:neiroha/data/adapters/elevenlabs_adapter.dart';
import 'package:neiroha/data/adapters/minimax_tts_adapter.dart';
import 'package:neiroha/data/adapters/index_tts_adapter.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

/// Describes a model available from a provider.
class ModelInfo {
  final String id;
  final String name;

  const ModelInfo({required this.id, this.name = ''});

  @override
  String toString() => name.isNotEmpty ? '$name ($id)' : id;
}

/// Base class for all TTS provider adapters.
abstract class TtsAdapter {
  ServiceRoute get serviceRoute => ServiceRoute.native;

  /// True only when audio is delivered before the upstream result completes.
  bool get supportsStreaming => false;

  /// Compatibility path for file-only adapters. It deliberately retains the
  /// queue slot until the non-cancellable legacy request actually completes.
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    cancellation.throwIfCancelled();
    final result = await synthesize(request);
    cancellation.throwIfCancelled();
    yield TtsAudioStarted(
      TtsAudioFormat.fromFileBytes(result.audioBytes, result.contentType),
    );
    yield TtsAudioChunk(result.audioBytes);
    yield const TtsSynthesisCompleted();
  }

  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();

  /// Fetch available speaker/voice names from the provider.
  /// Returns empty list if not supported.
  Future<List<String>> getSpeakers() async => [];

  /// Fetch available models from the provider.
  /// Returns empty list if not supported.
  Future<List<ModelInfo>> getModels() async => [];
}

/// Adapters whose upstream service can register a reusable cloned voice from
/// a reference recording (ElevenLabs instant voice clone, MiniMax
/// voice_clone). The returned label is stored as the character's
/// `presetVoiceName`; later synthesis treats it like any preset voice.
abstract interface class VoiceCloneCapable {
  Future<String> cloneVoice({
    required String name,
    required String audioPath,
    String? promptText,
    String? description,
  });
}

/// Voice pickers show cloud voices as `Display Name [voice_id]` so users see
/// a readable name while the adapter still sends the opaque id. Plain ids
/// (no brackets) pass through unchanged.
String voiceIdFromLabel(String label) {
  final match = RegExp(r'\[([^\[\]]+)\]\s*$').firstMatch(label.trim());
  return match != null ? match.group(1)!.trim() : label.trim();
}

/// Builds the `Display Name [voice_id]` label used by [voiceIdFromLabel].
String voiceLabel(String name, String id) {
  final n = name.trim();
  if (n.isEmpty || n == id) return id;
  return '$n [$id]';
}

/// Factory to create the correct adapter for a provider.
/// [modelName] overrides the provider's default model when provided.
TtsAdapter createAdapter(db.TtsProvider provider, {String? modelName}) {
  final model = modelName ?? provider.defaultModelName;
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
