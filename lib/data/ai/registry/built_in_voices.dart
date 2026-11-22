import 'package:neiroha/data/ai/providers/gemini/tts/gemini_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/mimo/tts/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

/// Voices a vendor ships with one TTS model, so the UI can nest them under
/// that model instead of listing every voice flat. Empty when the model has
/// no fixed list (account voices, clones, self-hosted engines).
List<String> builtInVoicesFor(AdapterType type, String modelKey) {
  final k = modelKey.trim().toLowerCase();
  if (k.isEmpty) return const [];
  return switch (type) {
    AdapterType.openaiTts =>
      OpenAiTtsAdapter.kModels.any((m) => m.id == k)
          ? OpenAiTtsAdapter.voicesForModel(k)
          : const [],
    AdapterType.geminiTts =>
      k.contains('tts') ? GeminiTtsAdapter.kPrebuiltVoices : const [],
    AdapterType.chatCompletionsTts =>
      ChatCompletionsTtsAdapter.builtInVoicesForMimoModel(k),
    _ => const [],
  };
}

/// Every built-in voice across [modelKeys], for de-duplicating fetched
/// voice lists.
Set<String> builtInVoicesAcross(AdapterType type, Iterable<String> modelKeys) =>
    {for (final m in modelKeys) ...builtInVoicesFor(type, m)};

/// [builtIn] first, then the other [stored] voices sorted, without those
/// in [hide] (voices built into the provider's other models).
List<String> mergeVoices(
  List<String> builtIn,
  Iterable<String> stored, {
  Set<String> hide = const {},
}) => [
  ...builtIn,
  ...(stored.where((v) => !builtIn.contains(v) && !hide.contains(v)).toList()
    ..sort()),
];
