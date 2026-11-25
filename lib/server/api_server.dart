import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/server/mcp/mcp_server.dart';
import 'package:neiroha/server/mcp/neiroha_mcp_tools.dart';

import 'jobs/speech_jobs.dart';
import 'speech_request_handler.dart';
import 'tracked_http_server.dart';
import 'package:neiroha/app_version.dart';

part 'api_server_config.dart';

/// Reported to MCP clients in `serverInfo.version`; keep in sync with the
/// pubspec version.
const String neirohaMcpServerVersion = appVersion;

class ApiServer {
  final AppDatabase db;
  TrackedHttpServer? _server;
  ApiServerConfig _config = const ApiServerConfig();
  final List<ApiLogEntry> _logs = <ApiLogEntry>[];
  final StreamController<List<ApiLogEntry>> _logController =
      StreamController<List<ApiLogEntry>>.broadcast();

  ApiServer({required this.db, Directory? jobsDir})
    : _jobs = speechJobs(db, dir: jobsDir);
  final JobsHandler _jobs;

  int get port => _config.port;
  String get bindHost => _config.bindHost;
  ApiServerConfig get config => _config;
  bool get isRunning => _server != null;
  bool get apiLogEnabled => _config.apiLogEnabled;
  List<ApiLogEntry> get logs => List.unmodifiable(_logs);

  Stream<List<ApiLogEntry>> watchLogs() async* {
    yield logs;
    yield* _logController.stream;
  }

  Future<void> setApiLogEnabled(bool enabled) async {
    _config = _config.copyWith(apiLogEnabled: enabled);
    await ApiServerConfig.saveLogEnabled(db, enabled);
    _emitLogs();
  }

  void clearLogs() {
    _logs.clear();
    _emitLogs();
  }

  /// Start with the persisted config (loaded from [AppSettings]). Pass an
  /// explicit [config] to override (used by the Settings screen after the user
  /// edits a knob and hits Restart).
  Future<void> start({ApiServerConfig? config}) async {
    if (_server != null) return;
    _config = config ?? await ApiServerConfig.load(db);

    final router = Router()
      ..post('/v1/audio/speech', SpeechRequestHandler(db).handle)
      ..get('/v1/audio/voices', _handleListVoices)
      ..get('/v1/models', _handleListModels)
      ..get('/speakers', _handleSpeakers)
      ..get('/health', _handleHealth)
      ..all('/mcp', _handleMcp);
    _jobs.mount(router);

    final handler = const Pipeline()
        .addMiddleware(_bodyLimitMiddleware(_config.maxBodyBytes))
        .addMiddleware(_rateLimitMiddleware(_config.rateLimitPerMin))
        .addMiddleware(_corsMiddleware(_config.corsOrigins))
        .addMiddleware(_apiKeyMiddleware(_config.apiKey))
        .addMiddleware(_apiLogMiddleware())
        .addHandler(router.call);

    final addr =
        InternetAddress.tryParse(_config.bindHost) ??
        InternetAddress.loopbackIPv4;
    _server = await serveTrackedHttp(handler, addr, _config.port);
    stdout.writeln(
      'Neiroha API server running on ${addr.address}:${_config.port}',
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _mcp = null; // rebuilt with the next config (CORS origins)
  }

  Future<void> restart({ApiServerConfig? config}) async {
    await stop();
    await start(config: config);
  }

  // ───────────────────── Middlewares ─────────────────────

  /// In-app request log for users exposing the local API to external tools.
  Middleware _apiLogMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        final startedAt = DateTime.now();
        try {
          final response = await inner(request);
          _recordApiLog(request, response.statusCode, startedAt);
          return response;
        } catch (error) {
          _recordApiLog(request, 500, startedAt, error: error.toString());
          rethrow;
        }
      };
    };
  }

  void _recordApiLog(
    Request request,
    int statusCode,
    DateTime startedAt, {
    String? error,
  }) {
    if (!_config.apiLogEnabled) return;
    final info =
        request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final path = request.url.path.isEmpty ? '/' : '/${request.url.path}';
    final query = request.url.hasQuery ? '?${request.url.query}' : '';
    final entry = ApiLogEntry(
      startedAt: startedAt,
      method: request.method,
      path: '$path$query',
      statusCode: statusCode,
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      remoteAddress: info?.remoteAddress.address ?? 'unknown',
      errorMessage: error,
    );
    _logs.insert(0, entry);
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }
    _emitLogs();
  }

  void _emitLogs() {
    if (!_logController.isClosed) {
      _logController.add(logs);
    }
  }

  /// Reject requests whose declared Content-Length exceeds [maxBytes].
  /// `0` disables the check.
  Middleware _bodyLimitMiddleware(int maxBytes) {
    return (Handler inner) {
      return (Request request) async {
        if (maxBytes > 0) {
          final declared = request.contentLength;
          if (declared != null && declared > maxBytes) {
            return jsonError(
              413,
              'Request body too large (limit ${maxBytes ~/ 1024} KiB)',
            );
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
        final info =
            request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
        final ip = info?.remoteAddress.address ?? 'unknown';
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(minutes: 1));
        final bucket = buckets.putIfAbsent(ip, () => Queue<DateTime>());
        while (bucket.isNotEmpty && bucket.first.isBefore(cutoff)) {
          bucket.removeFirst();
        }
        if (bucket.length >= perMin) {
          return jsonError(429, 'Rate limit exceeded ($perMin req/min)');
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
        final isAllowed =
            origin != null && (allowAll || allowed.contains(origin));

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
    'access-control-allow-headers': 'authorization, content-type, x-api-key',
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
          return jsonError(401, 'Missing or invalid API key');
        }
        return inner(request);
      };
    };
  }

  // ────────────── POST /v1/audio/speech ──────────────

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
        .map((b) => {'id': b.name, 'object': 'model', 'owned_by': 'neiroha'})
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
        speakers.add({'name': a.name, 'voice_id': a.id, 'model': bank.name});
      }
    }

    return Response.ok(
      jsonEncode(speakers),
      headers: {'content-type': 'application/json'},
    );
  }

  // ────────────── /mcp (Model Context Protocol) ──────────────

  McpServer? _mcp;

  Future<Response> _handleMcp(Request request) async {
    if (!_config.mcpEnabled) {
      return jsonError(404, 'MCP endpoint is disabled in Settings');
    }
    final host = _config.bindHost;
    final loopback =
        host == 'localhost' ||
        (InternetAddress.tryParse(host)?.isLoopback ?? false);
    if (!loopback && _config.apiKey == null) {
      // MCP can create providers, read local files and write outputs —
      // never expose it to the LAN without authentication.
      return jsonError(
        403,
        'MCP on a non-loopback bind host requires an API key',
      );
    }
    final mcp = _mcp ??= McpServer(
      tools: NeirohaMcpTools(db).build(),
      serverVersion: neirohaMcpServerVersion,
      instructions: NeirohaMcpTools.serverInstructions,
      allowedOrigins: _config.corsOrigins,
    );
    return mcp.handle(request);
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
}
