import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';

/// Persistent KV keys backing [ApiServerConfig]. Mirror [ApiServerConfig.load]
/// when adding fields.
class _SettingsKeys {
  static const bindHost = 'api.bindHost';
  static const port = 'api.port';
  static const apiKey = 'api.apiKey';
  static const corsOrigins = 'api.corsOrigins';
  static const rateLimitPerMin = 'api.rateLimitPerMin';
  static const maxBodyBytes = 'api.maxBodyBytes';
}

/// Snapshot of the security/network knobs that gate the local API. Loaded from
/// [AppSettings] at start; the Settings screen edits the underlying keys then
/// restarts the server.
class ApiServerConfig {
  /// Default to loopback so a fresh install does NOT expose the local provider
  /// keys to anyone on the LAN. Users opt into LAN access by setting `0.0.0.0`.
  final String bindHost;
  final int port;

  /// When non-null, every request (except `/health`) must include either
  /// `Authorization: Bearer <key>` or `X-API-Key: <key>`.
  final String? apiKey;

  /// Allowed CORS origins. Empty list = deny all cross-origin browsers.
  /// `['*']` allows any origin (only safe combined with [apiKey]).
  final List<String> corsOrigins;

  /// Sliding-window per-IP request budget. 0 disables.
  final int rateLimitPerMin;

  /// Reject requests advertising a Content-Length above this. Streaming reads
  /// beyond declared length aren't a realistic threat on a local API.
  final int maxBodyBytes;

  const ApiServerConfig({
    this.bindHost = '127.0.0.1',
    this.port = 8976,
    this.apiKey,
    this.corsOrigins = const [],
    this.rateLimitPerMin = 60,
    this.maxBodyBytes = 1048576,
  });

  static Future<ApiServerConfig> load(AppDatabase db) async {
    final host = await db.getSetting(_SettingsKeys.bindHost);
    final port = int.tryParse(await db.getSetting(_SettingsKeys.port) ?? '');
    final key = await db.getSetting(_SettingsKeys.apiKey);
    final cors = await db.getSetting(_SettingsKeys.corsOrigins);
    final rate = int.tryParse(
        await db.getSetting(_SettingsKeys.rateLimitPerMin) ?? '');
    final body =
        int.tryParse(await db.getSetting(_SettingsKeys.maxBodyBytes) ?? '');

    return ApiServerConfig(
      bindHost: (host == null || host.isEmpty) ? '127.0.0.1' : host,
      port: port ?? 8976,
      apiKey: (key == null || key.isEmpty) ? null : key,
      corsOrigins: cors == null || cors.trim().isEmpty
          ? const []
          : cors
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
      rateLimitPerMin: rate ?? 60,
      maxBodyBytes: body ?? 1048576,
    );
  }

  static Future<void> save(AppDatabase db, ApiServerConfig cfg) async {
    await db.setSetting(_SettingsKeys.bindHost, cfg.bindHost);
    await db.setSetting(_SettingsKeys.port, '${cfg.port}');
    await db.setSetting(_SettingsKeys.apiKey, cfg.apiKey ?? '');
    await db.setSetting(_SettingsKeys.corsOrigins, cfg.corsOrigins.join(','));
    await db.setSetting(
        _SettingsKeys.rateLimitPerMin, '${cfg.rateLimitPerMin}');
    await db.setSetting(_SettingsKeys.maxBodyBytes, '${cfg.maxBodyBytes}');
  }
}

class ApiServer {
  final AppDatabase db;
  HttpServer? _server;
  ApiServerConfig _config = const ApiServerConfig();

  ApiServer({required this.db});

  int get port => _config.port;
  String get bindHost => _config.bindHost;
  ApiServerConfig get config => _config;
  bool get isRunning => _server != null;

  /// Start with the persisted config (loaded from [AppSettings]). Pass an
  /// explicit [config] to override (used by the Settings screen after the user
  /// edits a knob and hits Restart).
  Future<void> start({ApiServerConfig? config}) async {
    if (_server != null) return;
    _config = config ?? await ApiServerConfig.load(db);

    final router = Router()
      ..post('/v1/audio/speech', _handleSpeech)
      ..get('/v1/audio/voices', _handleListVoices)
      ..get('/v1/models', _handleListModels)
      ..get('/speakers', _handleSpeakers)
      ..get('/health', _handleHealth);

    final handler = const Pipeline()
        .addMiddleware(_bodyLimitMiddleware(_config.maxBodyBytes))
        .addMiddleware(_rateLimitMiddleware(_config.rateLimitPerMin))
        .addMiddleware(_corsMiddleware(_config.corsOrigins))
        .addMiddleware(_apiKeyMiddleware(_config.apiKey))
        .addMiddleware(logRequests())
        .addHandler(router.call);

    final addr = InternetAddress.tryParse(_config.bindHost) ??
        InternetAddress.loopbackIPv4;
    _server = await shelf_io.serve(handler, addr, _config.port);
    stdout.writeln(
        'Neiroha API server running on ${addr.address}:${_config.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> restart({ApiServerConfig? config}) async {
    await stop();
    await start(config: config);
  }

  // ───────────────────── Middlewares ─────────────────────

  /// Reject requests whose declared Content-Length exceeds [maxBytes].
  /// `0` disables the check.
  Middleware _bodyLimitMiddleware(int maxBytes) {
    return (Handler inner) {
      return (Request request) async {
        if (maxBytes > 0) {
          final declared = request.contentLength;
          if (declared != null && declared > maxBytes) {
            return _jsonError(413,
                'Request body too large (limit ${maxBytes ~/ 1024} KiB)');
          }
        }
        return inner(request);
      };
    };
  }

  /// Per-IP sliding-window limiter. `0` disables.
  Middleware _rateLimitMiddleware(int perMin) {
    final buckets = <String, Queue<DateTime>>{};
    return (Handler inner) {
      return (Request request) async {
        if (perMin <= 0) return inner(request);
        // shelf_io stores the connection info under 'shelf.io.connection_info'.
        final info = request.context['shelf.io.connection_info']
            as HttpConnectionInfo?;
        final ip = info?.remoteAddress.address ?? 'unknown';
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(minutes: 1));
        final bucket = buckets.putIfAbsent(ip, () => Queue<DateTime>());
        while (bucket.isNotEmpty && bucket.first.isBefore(cutoff)) {
          bucket.removeFirst();
        }
        if (bucket.length >= perMin) {
          return _jsonError(429, 'Rate limit exceeded ($perMin req/min)');
        }
        bucket.addLast(now);
        return inner(request);
      };
    };
  }

  /// Allow only the configured origins. Empty list rejects every cross-origin
  /// request outright (browser-side; native HTTP clients ignore CORS anyway).
  /// `*` is treated as a literal allow-all.
  Middleware _corsMiddleware(List<String> allowed) {
    final allowAll = allowed.contains('*');
    return (Handler inner) {
      return (Request request) async {
        final origin = request.headers['origin'];
        final isAllowed = origin != null &&
            (allowAll || allowed.contains(origin));

        // Preflight short-circuit.
        if (request.method == 'OPTIONS') {
          if (origin == null) return Response(204);
          if (!isAllowed) return Response.forbidden('Origin not allowed');
          return Response(204, headers: _corsHeaders(origin, allowAll));
        }

        final response = await inner(request);
        if (origin != null && isAllowed) {
          return response.change(headers: _corsHeaders(origin, allowAll));
        }
        return response;
      };
    };
  }

  Map<String, String> _corsHeaders(String origin, bool allowAll) => {
        'access-control-allow-origin': allowAll ? '*' : origin,
        'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
        'access-control-allow-headers':
            'authorization, content-type, x-api-key',
        'access-control-max-age': '600',
        if (!allowAll) 'vary': 'origin',
      };

  /// Require `Authorization: Bearer <key>` or `X-API-Key: <key>` when an API
  /// key is configured. `/health` is always public so monitors can probe it.
  Middleware _apiKeyMiddleware(String? apiKey) {
    return (Handler inner) {
      return (Request request) async {
        if (apiKey == null || apiKey.isEmpty) return inner(request);
        if (request.url.path == 'health' || request.method == 'OPTIONS') {
          return inner(request);
        }
        final auth = request.headers['authorization'];
        final xkey = request.headers['x-api-key'];
        final supplied = (auth != null && auth.startsWith('Bearer '))
            ? auth.substring(7)
            : xkey;
        if (supplied != apiKey) {
          return _jsonError(401, 'Missing or invalid API key');
        }
        return inner(request);
      };
    };
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
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
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
              'owned_by': 'neiroha',
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
      jsonEncode({
        'status': 'ok',
        'host': _config.bindHost,
        'port': _config.port,
        'authRequired': _config.apiKey != null,
      }),
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
