part of 'api_server.dart';

// Server settings, their storage keys, and request log entries.

/// Persistent KV keys backing [ApiServerConfig]. Mirror [ApiServerConfig.load]
/// when adding fields.
class _SettingsKeys {
  static const bindHost = 'api.bindHost';
  static const port = 'api.port';
  static const apiKey = 'api.apiKey';
  static const corsOrigins = 'api.corsOrigins';
  static const rateLimitPerMin = 'api.rateLimitPerMin';
  static const maxBodyBytes = 'api.maxBodyBytes';
  static const apiLogEnabled = 'api.logEnabled';
  static const mcpEnabled = 'api.mcpEnabled';
  static const autoStart = 'api.autoStart';
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

  /// When enabled, request metadata is mirrored to the Settings > API log
  /// panel. Bodies and auth headers are intentionally never captured.
  final bool apiLogEnabled;

  /// Serve the MCP endpoint (`/mcp`) for AI agents. Defaults to on; the
  /// endpoint still refuses to run unauthenticated on a non-loopback bind.
  final bool mcpEnabled;

  /// Start the local API (and MCP) server automatically when the app
  /// launches. Off by default.
  final bool autoStart;

  const ApiServerConfig({
    this.bindHost = '127.0.0.1',
    this.port = 8976,
    this.apiKey,
    this.corsOrigins = const [],
    this.rateLimitPerMin = 60,
    this.maxBodyBytes = 1048576,
    this.apiLogEnabled = false,
    this.mcpEnabled = true,
    this.autoStart = false,
  });

  static Future<ApiServerConfig> load(AppDatabase db) async {
    final host = await db.getSetting(_SettingsKeys.bindHost);
    final port = int.tryParse(await db.getSetting(_SettingsKeys.port) ?? '');
    final key = await db.getSetting(_SettingsKeys.apiKey);
    final cors = await db.getSetting(_SettingsKeys.corsOrigins);
    final rate = int.tryParse(
      await db.getSetting(_SettingsKeys.rateLimitPerMin) ?? '',
    );
    final body = int.tryParse(
      await db.getSetting(_SettingsKeys.maxBodyBytes) ?? '',
    );
    final apiLogEnabled = await db.getSetting(_SettingsKeys.apiLogEnabled);
    final mcpEnabled = await db.getSetting(_SettingsKeys.mcpEnabled);
    final autoStart = await db.getSetting(_SettingsKeys.autoStart);

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
      apiLogEnabled: _parseBool(apiLogEnabled),
      mcpEnabled: mcpEnabled == null || mcpEnabled.isEmpty
          ? true
          : _parseBool(mcpEnabled),
      autoStart: _parseBool(autoStart),
    );
  }

  static Future<void> save(AppDatabase db, ApiServerConfig cfg) async {
    await db.setSetting(_SettingsKeys.bindHost, cfg.bindHost);
    await db.setSetting(_SettingsKeys.port, '${cfg.port}');
    await db.setSetting(_SettingsKeys.apiKey, cfg.apiKey ?? '');
    await db.setSetting(_SettingsKeys.corsOrigins, cfg.corsOrigins.join(','));
    await db.setSetting(
      _SettingsKeys.rateLimitPerMin,
      '${cfg.rateLimitPerMin}',
    );
    await db.setSetting(_SettingsKeys.maxBodyBytes, '${cfg.maxBodyBytes}');
    await saveLogEnabled(db, cfg.apiLogEnabled);
    await db.setSetting(
      _SettingsKeys.mcpEnabled,
      cfg.mcpEnabled ? 'true' : 'false',
    );
    await saveAutoStart(db, cfg.autoStart);
  }

  static Future<void> saveAutoStart(AppDatabase db, bool enabled) {
    return db.setSetting(_SettingsKeys.autoStart, enabled ? 'true' : '');
  }

  static Future<void> saveLogEnabled(AppDatabase db, bool enabled) {
    return db.setSetting(_SettingsKeys.apiLogEnabled, enabled ? 'true' : '');
  }

  ApiServerConfig copyWith({
    String? bindHost,
    int? port,
    String? apiKey,
    List<String>? corsOrigins,
    int? rateLimitPerMin,
    int? maxBodyBytes,
    bool? apiLogEnabled,
    bool? mcpEnabled,
    bool? autoStart,
  }) {
    return ApiServerConfig(
      bindHost: bindHost ?? this.bindHost,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      corsOrigins: corsOrigins ?? this.corsOrigins,
      rateLimitPerMin: rateLimitPerMin ?? this.rateLimitPerMin,
      maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
      apiLogEnabled: apiLogEnabled ?? this.apiLogEnabled,
      mcpEnabled: mcpEnabled ?? this.mcpEnabled,
      autoStart: autoStart ?? this.autoStart,
    );
  }

  static bool _parseBool(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}

class ApiLogEntry {
  const ApiLogEntry({
    required this.startedAt,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.remoteAddress,
    this.errorMessage,
  });

  final DateTime startedAt;
  final String method;
  final String path;
  final int statusCode;
  final int durationMs;
  final String remoteAddress;
  final String? errorMessage;
}
