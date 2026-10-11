import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// One tool exposed over MCP. [handler] receives the validated-by-convention
/// `arguments` object and returns any JSON-encodable value; throwing
/// [McpToolError] (or anything else) yields an `isError` tool result so the
/// calling model can read the message and recover.
class McpTool {
  final String name;
  final String title;
  final String description;
  final Map<String, dynamic> inputSchema;
  final bool readOnly;
  final bool destructive;
  final bool openWorld;
  final Future<Object?> Function(Map<String, dynamic> args) handler;

  const McpTool({
    required this.name,
    required this.title,
    required this.description,
    required this.inputSchema,
    required this.handler,
    this.readOnly = false,
    this.destructive = false,
    this.openWorld = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': inputSchema,
    'annotations': {
      'title': title,
      'readOnlyHint': readOnly,
      'destructiveHint': destructive,
      'idempotentHint': readOnly,
      'openWorldHint': openWorld,
    },
  };
}

/// Error raised by tool handlers for bad arguments or missing entities.
class McpToolError implements Exception {
  final String message;
  const McpToolError(this.message);

  @override
  String toString() => message;
}

/// Minimal stateless MCP server speaking the Streamable HTTP transport:
/// every JSON-RPC message is a `POST /mcp` and every response is plain
/// `application/json` (no SSE stream, no session id). That subset is
/// accepted by all mainstream MCP clients and keeps the server free of
/// per-client state.
class McpServer {
  McpServer({
    required this.tools,
    required this.serverVersion,
    this.instructions,
    this.allowedOrigins = const [],
  });

  final List<McpTool> tools;
  final String serverVersion;
  final String? instructions;

  /// Browser origins allowed to call the endpoint (DNS-rebinding guard).
  /// Requests without an `Origin` header (CLI / desktop agents) always pass.
  final List<String> allowedOrigins;

  static const String _defaultProtocolVersion = '2025-06-18';

  late final Map<String, McpTool> _toolsByName = {
    for (final t in tools) t.name: t,
  };

  Future<Response> handle(Request request) async {
    final origin = request.headers['origin'];
    if (origin != null &&
        !allowedOrigins.contains('*') &&
        !allowedOrigins.contains(origin)) {
      return _json(403, _error(null, -32000, 'Origin not allowed'));
    }

    if (request.method == 'GET' || request.method == 'DELETE') {
      // No server-initiated stream and no sessions to terminate.
      return Response(405, headers: {'allow': 'POST'});
    }
    if (request.method != 'POST') {
      return Response(405, headers: {'allow': 'POST'});
    }

    dynamic payload;
    try {
      payload = jsonDecode(await request.readAsString());
    } catch (_) {
      return _json(400, _error(null, -32700, 'Parse error'));
    }

    if (payload is List) {
      if (payload.isEmpty) {
        return _json(400, _error(null, -32600, 'Empty batch'));
      }
      final responses = <Map<String, dynamic>>[];
      for (final msg in payload) {
        final r = await _dispatch(msg);
        if (r != null) responses.add(r);
      }
      if (responses.isEmpty) return Response(202);
      return _json(200, responses);
    }

    final response = await _dispatch(payload);
    if (response == null) return Response(202);
    return _json(200, response);
  }

  /// Returns `null` for notifications and client responses.
  Future<Map<String, dynamic>?> _dispatch(dynamic msg) async {
    if (msg is! Map<String, dynamic>) {
      return _error(null, -32600, 'Invalid request');
    }
    final method = msg['method'];
    final id = msg['id'];
    if (method is! String) {
      // A response to a server request (we never send any) — ignore.
      return null;
    }
    final isNotification = !msg.containsKey('id');
    final params = msg['params'] is Map<String, dynamic>
        ? msg['params'] as Map<String, dynamic>
        : const <String, dynamic>{};

    try {
      final result = await _invoke(method, params);
      if (isNotification) return null;
      return {'jsonrpc': '2.0', 'id': id, 'result': result};
    } on _RpcError catch (e) {
      if (isNotification) return null;
      return _error(id, e.code, e.message);
    } catch (e) {
      if (isNotification) return null;
      return _error(id, -32603, e.toString());
    }
  }

  Future<Object?> _invoke(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'initialize':
        final requested = params['protocolVersion'];
        return {
          'protocolVersion': requested is String && requested.isNotEmpty
              ? requested
              : _defaultProtocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {
            'name': 'neiroha',
            'title': 'Neiroha Dubbing Workstation',
            'version': serverVersion,
          },
          if (instructions != null) 'instructions': instructions,
        };
      case 'ping':
        return <String, dynamic>{};
      case 'tools/list':
        return {'tools': tools.map((t) => t.toJson()).toList()};
      case 'tools/call':
        return _callTool(params);
      default:
        if (method.startsWith('notifications/')) return null;
        throw _RpcError(-32601, 'Method not found: $method');
    }
  }

  Future<Map<String, dynamic>> _callTool(Map<String, dynamic> params) async {
    final name = params['name'];
    final tool = name is String ? _toolsByName[name] : null;
    if (tool == null) {
      throw _RpcError(-32602, 'Unknown tool: $name');
    }
    final rawArgs = params['arguments'];
    final args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};
    try {
      final result = await tool.handler(args);
      final structured = result is Map<String, dynamic>
          ? result
          : <String, dynamic>{'result': result};
      return {
        'content': [
          {
            'type': 'text',
            'text': const JsonEncoder.withIndent('  ').convert(structured),
          },
        ],
        'structuredContent': structured,
        'isError': false,
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': 'Error: $e'},
        ],
        'isError': true,
      };
    }
  }

  static Map<String, dynamic> _error(Object? id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };

  static Response _json(int status, Object body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json'},
  );
}

class _RpcError implements Exception {
  final int code;
  final String message;
  const _RpcError(this.code, this.message);
}
