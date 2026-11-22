import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_dio.dart';
import 'package:neiroha/data/ai/providers/common/adapter_backed_connection.dart';
import 'package:neiroha/domain/ai/ai.dart';

import 'gemini_endpoint.dart';
import 'llm/gemini_language_model.dart';
import 'music/gemini_music_generator.dart';
import 'realtime/gemini_realtime_model.dart';
import 'stt/gemini_streaming_transcriber.dart';
import 'stt/gemini_transcriber.dart';
import 'translate/gemini_speech_translator.dart';

/// One AI Studio key: native TTS (adapter), generateContent LLMs,
/// Interactions transcription and Lyria songs, and Live conversation /
/// transcription / translation.
class GeminiConnection extends AdapterBackedConnection {
  GeminiConnection(super.plugin, super.config);

  GeminiEndpoint get endpoint => GeminiEndpoint(config.baseUrl, config.apiKey);

  @override
  AiProtocol? manualProtocol(AiCapability cap, String modelId) => switch (cap) {
    AiCapability.tts => AiProtocol.native,
    AiCapability.llm => AiProtocol.geminiGenerateContent,
    AiCapability.stt =>
      modelId.contains('-live')
          ? AiProtocol.geminiLive
          : AiProtocol.geminiInteractions,
    AiCapability.realtime || AiCapability.translate => AiProtocol.geminiLive,
    AiCapability.music => AiProtocol.geminiInteractions,
    _ => null,
  };

  @override
  CapabilityModel? open(AiCapability cap, String modelId) {
    final d = describe(cap, modelId);
    if (d == null) return null;
    return switch ((cap, d.protocol)) {
      (AiCapability.llm, AiProtocol.geminiGenerateContent) =>
        GeminiLanguageModel(d, endpoint),
      (AiCapability.stt, AiProtocol.geminiInteractions) => GeminiTranscriber(
        d,
        endpoint,
      ),
      (AiCapability.stt, AiProtocol.geminiLive) => GeminiStreamingTranscriber(
        d,
        endpoint,
      ),
      (AiCapability.realtime, _) => GeminiRealtimeModel(d, endpoint),
      (AiCapability.translate, _) => GeminiSpeechTranslator(d, endpoint),
      (AiCapability.music, _) => GeminiMusicGenerator(d, endpoint),
      _ => super.open(cap, modelId),
    };
  }

  /// TTS through the adapter; everything else from one native `GET models`,
  /// which also lists Live (`bidiGenerateContent`) models.
  @override
  Future<Map<AiCapability, CapabilityHealth>> check() async {
    final tts = await checkTts();
    final others = capabilities.where((c) => c != AiCapability.tts);
    try {
      final visible = await withCancel(null, endpoint.apiKey, (token) async {
        final response = await endpoint
            .dio(timeout: const Duration(seconds: 30))
            .get<dynamic>(
              'models',
              queryParameters: {'pageSize': 1000},
              cancelToken: token,
            );
        final data = response.data;
        return {
          if (data is Map && data['models'] is List)
            for (final m in (data['models'] as List).whereType<Map>())
              '${m['name']}'.replaceFirst('models/', ''),
        };
      });
      return {
        AiCapability.tts: tts,
        for (final cap in others)
          cap: () {
            final seen = [
              for (final m in models(cap))
                if (visible.contains(m.id)) m.id,
            ];
            return CapabilityHealth(
              seen.isEmpty ? HealthState.unavailable : HealthState.ok,
              models: seen,
            );
          }(),
      };
    } on AiProviderException catch (error) {
      final denied = error.statusCode == 401 || error.statusCode == 403;
      return {
        AiCapability.tts: tts,
        for (final cap in others)
          cap: CapabilityHealth(
            denied ? HealthState.failed : HealthState.unknown,
            message: '$error',
          ),
      };
    }
  }
}
