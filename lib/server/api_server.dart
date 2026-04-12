import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:q_vox_lab/data/database/app_database.dart';
import 'package:q_vox_lab/data/adapters/tts_adapter.dart';

class ApiServer {
  final AppDatabase db;
  HttpServer? _server;
  int _port = 8976;

  ApiServer({required this.db});

  int get port => _port;
  bool get isRunning => _server != null;

  Future<void> start({int port = 8976}) async {
    if (_server != null) return;
    _port = port;

    final router = Router()
      ..post('/v1/audio/speech', _handleSpeech)
      ..get('/v1/audio/voices', _handleListVoices)
      ..get('/v1/models', _handleListModels)
      ..get('/speakers', _handleSpeakers)
      ..get('/health', _handleHealth);

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    print('Q-Vox-Lab API server running on port $_port');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ────────────── POST /v1/audio/speech ──────────────

  Future<Response> _handleSpeech(Request request) async {
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
      final provider =
          providers.where((p) => p.id == asset!.providerId).firstOrNull;

      if (provider == null) {
        return _jsonError(500, 'Provider not found for voice');
      }

      // Build the adapter and synthesize
      final adapter = createAdapter(provider);
      final ttsRequest = TtsRequest(
        text: input,
        voice: voice,
        speed: speed,
        responseFormat: responseFormat,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
        voiceInstruction: asset.voiceInstruction,
        presetVoiceName: asset.presetVoiceName,
      );

      final result = await adapter.synthesize(ttsRequest);

      return Response.ok(result.audioBytes,
          headers: {'content-type': result.contentType});
    } catch (e) {
      return _jsonError(500, e.toString());
    }
  }

  /// Look up a voice asset by name within a specific bank (matched by bank name).
  Future<VoiceAsset?> _resolveVoiceInBank(
      String bankName, String voiceName) async {
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
      if (a != null && a.enabled && a.name.toLowerCase() == voiceName.toLowerCase()) {
        return a;
      }
    }
    return null;
  }

  // ────────────── GET /v1/audio/voices ──────────────

  Future<Response> _handleListVoices(Request request) async {
    final activeBanks = await db.getActiveBanks();
    final allAssets = await db.getAllVoiceAssets();
    final assetMap = {for (final a in allAssets) a.id: a};
    final providers = await db.getAllProviders();
    final providerMap = {for (final p in providers) p.id: p};

    final voices = <Map<String, dynamic>>[];
    for (final bank in activeBanks) {
      final members = await db.getBankMembers(bank.id);
      for (final m in members) {
        final a = assetMap[m.voiceAssetId];
        if (a == null || !a.enabled) continue;
        final p = providerMap[a.providerId];
        voices.add({
          'voice_id': a.name,
          'name': a.name,
          'description': a.description ?? '',
          'provider': p?.name ?? 'unknown',
          'model': bank.name,
          'task_mode': a.taskMode,
        });
      }
    }

    return Response.ok(
      jsonEncode({'voices': voices}),
      headers: {'content-type': 'application/json'},
    );
  }

  // ────────────── GET /v1/models ──────────────

  Future<Response> _handleListModels(Request request) async {
    final activeBanks = await db.getActiveBanks();
    final models = activeBanks
        .map((b) => {
              'id': b.name,
              'object': 'model',
              'owned_by': 'q-vox-lab',
            })
        .toList();

    return Response.ok(
      jsonEncode({'object': 'list', 'data': models}),
      headers: {'content-type': 'application/json'},
    );
  }

  // ────────────── GET /speakers ──────────────

  Future<Response> _handleSpeakers(Request request) async {
    final activeBanks = await db.getActiveBanks();
    final allAssets = await db.getAllVoiceAssets();
    final assetMap = {for (final a in allAssets) a.id: a};

    final speakers = <Map<String, dynamic>>[];
    for (final bank in activeBanks) {
      final members = await db.getBankMembers(bank.id);
      for (final m in members) {
        final a = assetMap[m.voiceAssetId];
        if (a == null || !a.enabled) continue;
        speakers.add({
          'name': a.name,
          'voice_id': a.id,
          'model': bank.name,
        });
      }
    }

    return Response.ok(
      jsonEncode(speakers),
      headers: {'content-type': 'application/json'},
    );
  }

  // ────────────── GET /health ──────────────

  Future<Response> _handleHealth(Request request) async {
    return Response.ok(
      jsonEncode({'status': 'ok', 'port': _port}),
      headers: {'content-type': 'application/json'},
    );
  }

  // ────────────── Helpers ──────────────

  Response _jsonError(int status, String message) {
    return Response(status,
        body: jsonEncode({'error': message}),
        headers: {'content-type': 'application/json'});
  }
}
