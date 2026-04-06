import 'dart:typed_data';

import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/data/adapters/openai_compatible_adapter.dart';
import 'package:q_vox_lab/data/adapters/chat_completions_tts_adapter.dart';
import 'package:q_vox_lab/data/adapters/cosyvoice_adapter.dart';

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

  // Qwen3 specific
  final String? voiceInstruction;

  // OpenAI-compatible preset
  final String? presetVoiceName;

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
  });
}

/// Result of a TTS synthesis call.
class TtsResult {
  final Uint8List audioBytes;
  final String contentType;

  const TtsResult({required this.audioBytes, required this.contentType});
}

/// Base class for all TTS provider adapters.
abstract class TtsAdapter {
  Future<TtsResult> synthesize(TtsRequest request);
  Future<bool> healthCheck();

  /// Fetch available speaker/voice names from the provider.
  /// Returns empty list if not supported.
  Future<List<String>> getSpeakers() async => [];
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
    // TODO: Add gptSovits, qwen3Native adapters
    default:
      throw UnimplementedError(
          'Adapter not implemented for: ${provider.adapterType}');
  }
}
