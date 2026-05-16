import 'dart:typed_data';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/adapters/openai_compatible_adapter.dart';
import 'package:neiroha/data/adapters/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/adapters/cosyvoice_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/adapters/gpt_sovits_adapter.dart';
import 'package:neiroha/data/adapters/azure_tts_adapter.dart';
import 'package:neiroha/data/adapters/system_tts_adapter.dart';
import 'package:neiroha/data/adapters/gemini_tts_adapter.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';

/// Request payload for TTS synthesis, unified across all adapters.
class TtsRequest {
  final String text;
  final String voice;
  final double speed;
  final String? responseFormat;

  // GPT-SoVITS specific
  final String? refAudioPath;
  final String? promptText;
  final String? promptLang;
  final String? textLang;

  // Per-call style / direction text for adapters that expose instruction
  // control (MiMo chat-completions TTS, CosyVoice instruct, VoxCPM2, Gemini).
  final String? voiceInstruction;

  // OpenAI-compatible preset
  final String? presetVoiceName;

  // MiMo V2.5 VoiceClone: data:audio/mpeg;base64,... or data:audio/wav;base64,...
  final String? voiceClonePromptBase64;

  // Audio tag prefix prepended to text, e.g. "(磁性)" or "(兴奋|颤抖)"
  final String? audioTagPrefix;

  const TtsRequest({
    required this.text,
    required this.voice,
    this.speed = 1.0,
    this.responseFormat,
    this.refAudioPath,
    this.promptText,
    this.promptLang,
    this.textLang,
    this.voiceInstruction,
    this.presetVoiceName,
    this.voiceClonePromptBase64,
    this.audioTagPrefix,
  });
}

/// Result of a TTS synthesis call.
class TtsResult {
  final Uint8List audioBytes;
  final String contentType;

  const TtsResult({required this.audioBytes, required this.contentType});
}

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
  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();

  /// Fetch available speaker/voice names from the provider.
  /// Returns empty list if not supported.
  Future<List<String>> getSpeakers() async => [];

  /// Fetch available models from the provider.
  /// Returns empty list if not supported.
  Future<List<ModelInfo>> getModels() async => [];
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
    default:
      throw UnimplementedError(
        'Adapter not implemented for: ${provider.adapterType}',
      );
  }
}
