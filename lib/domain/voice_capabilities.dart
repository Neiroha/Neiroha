import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

/// Which per-call style controls a character's engine understands. Shared by
/// the Phase TTS editor (to build requests) and its sentence settings
/// dialog (to decide which fields to show / keep).
abstract final class VoiceCapabilities {
  /// Free-text style / emotion direction sent with each request.
  static bool supportsVoiceInstruction(
    db.VoiceAsset asset,
    db.TtsProvider provider,
  ) {
    return switch (provider.adapterType) {
      'chatCompletionsTts' => isMimoTtsModel(asset, provider),
      'openaiTts' => OpenAiTtsAdapter.supportsInstructions(
        asset.modelName ?? provider.defaultModelName,
      ),
      'cosyvoice' => true,
      'voxcpm2Native' => true,
      'geminiTts' => true,
      'elevenLabs' => true,
      'minimaxTts' => true,
      'indexTts' => true,
      'irodori' => asset.refAudioPath?.trim().isNotEmpty == true,
      _ => false,
    };
  }

  /// A fixed sampling seed, so the same text gives the same take.
  static bool supportsSeed(String? adapterType) =>
      const {'cosyvoice', 'gptSovits', 'irodori'}.contains(adapterType);

  /// Inline audio tags such as `(紧张|深呼吸)` prefixed to the text.
  static bool supportsAudioTags(db.VoiceAsset asset, db.TtsProvider provider) =>
      isMimoTtsModel(asset, provider);

  static bool isMimoTtsModel(db.VoiceAsset asset, db.TtsProvider provider) {
    final model = (asset.modelName ?? provider.defaultModelName).toLowerCase();
    return provider.adapterType == 'chatCompletionsTts' &&
        model.contains('mimo') &&
        (model.contains('tts') ||
            model.contains('voiceclone') ||
            model.contains('voicedesign'));
  }
}
