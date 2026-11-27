import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/domain/ai/capability.dart';

/// Badge labels for a listed non-TTS model: what the provider's catalog
/// mounts it as, otherwise a guess from the id (`mimo-v2.5-asr` → ASR).
List<String> modelBadges(String modelId, [ProviderConnection? connection]) {
  final mounted = <AiCapability>{
    if (connection != null)
      for (final cap in connection.capabilities)
        if (cap != AiCapability.tts &&
            connection.models(cap).any((m) => m.id == modelId))
          cap,
  };
  if (mounted.isNotEmpty) {
    return [
      for (final cap in AiCapability.values)
        if (mounted.contains(cap)) _label(cap),
    ];
  }
  final k = modelId.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(k);
  if (has(r'asr|transcri|whisper|speech-to-text|(^|[-_])stt([-_]|$)')) {
    return const ['ASR'];
  }
  if (has(r'realtime|[-_]live([-_]|$)|native-audio')) return const ['Realtime'];
  if (has(r'translat')) return const ['Translate'];
  if (has(r'lyria|music|song')) return const ['Music'];
  if (has(r'embed')) return const ['Embedding'];
  if (has(r'imagen|image|dall-e|veo|video|sora')) return const ['Image'];
  if (has(r'omni|-vision|mimo-v2(\.5)?$') ||
      (k.contains('gpt-4o') && !k.contains('transcribe'))) {
    return const ['LLM', 'ASR'];
  }
  return const ['LLM'];
}

String _label(AiCapability cap) => switch (cap) {
  AiCapability.llm => 'LLM',
  AiCapability.stt => 'ASR',
  AiCapability.realtime => 'Realtime',
  AiCapability.translate => 'Translate',
  AiCapability.music => 'Music',
  AiCapability.vc => 'VC',
  AiCapability.vad => 'VAD',
  AiCapability.tts => 'TTS',
};
