import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'speech_stream_response.dart';
import 'tracked_http_server.dart';

class SpeechRequestHandler {
  const SpeechRequestHandler(this.db);
  final AppDatabase db;
  Future<Response> handle(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final input = json['input'] as String?;
      final voice = json['voice'] as String?;
      final speed = (json['speed'] as num?)?.toDouble() ?? 1.0;
      final responseFormat = json['response_format'] as String?;
      final model = json['model'] as String?;

      if (input == null || voice == null) {
        return _jsonError(400, 'Missing required fields: input, voice');
      }

      // Resolve voice asset — if `model` is given, treat it as a bank name
      // and look up the voice within that bank's members.
      VoiceAsset? asset;
      if (model != null && model.isNotEmpty) {
        asset = await _resolveVoiceInBank(model, voice);
      }
      // Fallback: look up by voice name globally
      asset ??= await db.getVoiceAssetByName(voice);

      if (asset == null) {
        return _jsonError(404, 'Voice "$voice" not found');
      }

      // Resolve provider
      final providers = await db.getAllProviders();
      final provider = providers
          .where((p) => p.id == asset!.providerId)
          .firstOrNull;

      if (provider == null) {
        return _jsonError(500, 'Provider not found for voice');
      }

      // Submit through the global TTS scheduler so local API calls obey the
      // same provider limits as the desktop UI.
      final ttsRequest = TtsRequest(
        text: input,
        voice: voice,
        speed: speed,
        responseFormat: responseFormat,
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
        voiceInstruction: asset.voiceInstruction,
        presetVoiceName: asset.presetVoiceName,
      );

      if (json['stream'] == true) {
        if (responseFormat != 'pcm') {
          return _jsonError(400, 'Streaming requires response_format: pcm');
        }
        return await streamSpeechResponse(
          provider: provider,
          modelName: asset.modelName,
          request: ttsRequest,
          clientClosed:
              request.context[clientClosedContextKey] as Future<void>?,
        );
      }
      final result = await TtsQueueService.instance.synthesize(
        provider: provider,
        modelName: asset.modelName,
        source: 'External API',
        label: '$voice: $input',
        request: ttsRequest,
      );

      return Response.ok(
        result.audioBytes,
        headers: {'content-type': result.contentType},
      );
    } catch (e) {
      return _jsonError(500, e.toString());
    }
  }

  /// Look up a voice asset by name within a specific bank (matched by bank name).
  Future<VoiceAsset?> _resolveVoiceInBank(
    String bankName,
    String voiceName,
  ) async {
    final banks = await db.getActiveBanks();
    final bank = banks
        .where((b) => b.name.toLowerCase() == bankName.toLowerCase())
        .firstOrNull;
    if (bank == null) return null;

    final members = await db.getBankMembers(bank.id);
    final assets = await db.getAllVoiceAssets();
    final assetMap = {for (final a in assets) a.id: a};

    for (final m in members) {
      final a = assetMap[m.voiceAssetId];
      if (a != null &&
          a.enabled &&
          a.name.toLowerCase() == voiceName.toLowerCase()) {
        return a;
      }
    }
    return null;
  }

  Response _jsonError(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'content-type': 'application/json'},
  );
}
