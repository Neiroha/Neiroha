import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart';

/// A request the local API refuses, with the HTTP status to answer.
class SpeechApiException implements Exception {
  const SpeechApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// An OpenAI-style speech body resolved to a character and its provider.
class ResolvedSpeech {
  const ResolvedSpeech(this.asset, this.provider, this.request);
  final VoiceAsset asset;
  final TtsProvider provider;
  final TtsRequest request;
}

/// Resolves `input` / `voice` / `model` (bank name) / `speed` /
/// `response_format` / `apply_chain` of a speech body.
Future<ResolvedSpeech> resolveSpeech(
  AppDatabase db,
  Map<String, dynamic> json,
) async {
  final input = json['input'];
  final voice = json['voice'];
  if (input is! String || voice is! String) {
    throw const SpeechApiException(
      400,
      'Missing required fields: input, voice',
    );
  }
  final model = json['model'] as String?;
  // With `model`, the voice is looked up in the bank of that name first.
  VoiceAsset? asset;
  if (model != null && model.isNotEmpty) {
    asset = await _voiceInBank(db, model, voice);
  }
  asset ??= await db.getVoiceAssetByName(voice);
  if (asset == null) {
    throw SpeechApiException(404, 'Voice "$voice" not found');
  }
  final providers = await db.getAllProviders();
  final provider = providers
      .where((p) => p.id == asset!.providerId)
      .firstOrNull;
  if (provider == null) {
    throw const SpeechApiException(500, 'Provider not found for voice');
  }
  return ResolvedSpeech(
    asset,
    provider,
    TtsRequest(
      text: input,
      voice: voice,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      responseFormat: json['response_format'] as String?,
      textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
      refAudioPath: asset.refAudioPath,
      promptText: asset.promptText,
      promptLang: asset.promptLang,
      voiceInstruction: asset.voiceInstruction,
      presetVoiceName: asset.presetVoiceName,
      // Neiroha extension: the character's processing chain runs unless the
      // caller sends `"apply_chain": false`.
      voiceAssetId: json['apply_chain'] == false ? null : asset.id,
    ),
  );
}

Future<VoiceAsset?> _voiceInBank(
  AppDatabase db,
  String bankName,
  String voiceName,
) async {
  final bank = (await db.getActiveBanks())
      .where((b) => b.name.toLowerCase() == bankName.toLowerCase())
      .firstOrNull;
  if (bank == null) return null;
  final members = await db.getBankMembers(bank.id);
  final assets = {for (final a in await db.getAllVoiceAssets()) a.id: a};
  for (final m in members) {
    final a = assets[m.voiceAssetId];
    if (a != null &&
        a.enabled &&
        a.name.toLowerCase() == voiceName.toLowerCase()) {
      return a;
    }
  }
  return null;
}
