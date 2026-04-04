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
      ..get('/v1/models', _handleListModels)
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

  Future<Response> _handleSpeech(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final input = json['input'] as String?;
      final voice = json['voice'] as String?;
      final speed = (json['speed'] as num?)?.toDouble() ?? 1.0;
      final responseFormat = json['response_format'] as String?;

      if (input == null || voice == null) {
        return Response(400,
            body: jsonEncode(
                {'error': 'Missing required fields: input, voice'}),
            headers: {'content-type': 'application/json'});
      }

      // Look up VoiceAsset by name
      final asset = await db.getVoiceAssetByName(voice);
      if (asset == null) {
        return Response(404,
            body: jsonEncode({'error': 'Voice "$voice" not found'}),
            headers: {'content-type': 'application/json'});
      }

      // Look up the provider
      final providers = await db.getAllProviders();
      final provider =
          providers.where((p) => p.id == asset.providerId).firstOrNull;
      if (provider == null) {
        return Response(500,
            body: jsonEncode({'error': 'Provider not found for voice'}),
            headers: {'content-type': 'application/json'});
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
      return Response.internalServerError(
          body: jsonEncode({'error': e.toString()}),
          headers: {'content-type': 'application/json'});
    }
  }

  Future<Response> _handleListModels(Request request) async {
    final assets = await db.getAllVoiceAssets();
    final models = assets
        .where((a) => a.enabled)
        .map((a) => {
              'id': a.name,
              'object': 'model',
              'owned_by': 'q-vox-lab',
            })
        .toList();

    return Response.ok(
      jsonEncode({'object': 'list', 'data': models}),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleHealth(Request request) async {
    return Response.ok(
      jsonEncode({'status': 'ok', 'port': _port}),
      headers: {'content-type': 'application/json'},
    );
  }
}
