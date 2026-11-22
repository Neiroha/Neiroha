import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/domain/ai/ai_exception.dart';
import 'package:neiroha/domain/ai/events/session_events.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

/// `wss://host/v1/<path>?…` derived from an HTTP(S) base URL.
Uri websocketUri(String baseUrl, String path, Map<String, String> query) {
  final raw = baseUrl.trim().endsWith('/') ? baseUrl.trim() : '$baseUrl/';
  final base = Uri.parse(raw);
  return base
      .resolve(path)
      .replace(
        scheme: base.scheme == 'http' ? 'ws' : 'wss',
        queryParameters: query.isEmpty ? null : query,
      );
}

/// JSON-event WebSocket session shared by OpenAI-style realtime protocols.
/// Subclasses map server events to [AiSessionEvent]s and build client events.
abstract class JsonSocketSession implements AudioStreamSession {
  JsonSocketSession(this.socket) {
    _subscription = socket.listen(
      _onMessage,
      onError: (Object error, StackTrace stack) => fail(error, stack),
      onDone: () {
        if (!_closed) {
          fail(const AiProviderException('Connection closed by the server.'));
        }
      },
    );
  }

  static Future<WebSocket> connectSocket(
    Uri uri,
    String apiKey, {
    Duration timeout = const Duration(seconds: 30),
  }) => WebSocket.connect(
    uri.toString(),
    headers: {if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey'},
  ).timeout(timeout);

  final WebSocket socket;
  late final StreamSubscription<dynamic> _subscription;
  final _events = StreamController<AiSessionEvent>();
  final _waiters = <_Waiter>[];
  bool _closed = false;

  @override
  Stream<AiSessionEvent> get events => _events.stream;

  /// Maps one server event to public events. Called before waiters.
  Iterable<AiSessionEvent> decode(Map<String, dynamic> event);

  void send(Map<String, Object?> event) {
    if (_closed) throw StateError('Session is closed.');
    socket.add(jsonEncode(event));
  }

  void appendAudio(String type, Uint8List pcm16) =>
      send({'type': type, 'audio': base64Encode(pcm16)});

  /// Completes with the first server event matching [test].
  Future<Map<String, dynamic>> waitFor(
    bool Function(Map<String, dynamic> event) test, {
    Duration timeout = const Duration(minutes: 2),
  }) {
    final waiter = _Waiter(test);
    _waiters.add(waiter);
    return waiter.completer.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(waiter);
        throw TimeoutException('Realtime session timed out.', timeout);
      },
    );
  }

  void _onMessage(dynamic message) {
    if (_closed || message is! String) return;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) return;
      final event = Map<String, dynamic>.from(decoded);
      if (event['type'] == 'error') {
        final error = event['error'];
        fail(
          AiProviderException(
            error is Map
                ? '${error['code'] ?? error['type'] ?? 'error'}: '
                      '${error['message'] ?? ''}'
                : jsonEncode(event),
          ),
        );
        return;
      }
      for (final out in decode(event)) {
        _events.add(out);
      }
      for (final waiter in List.of(_waiters)) {
        if (waiter.test(event)) {
          _waiters.remove(waiter);
          waiter.completer.complete(event);
        }
      }
    } catch (error, stack) {
      fail(error, stack);
    }
  }

  void fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _events.addError(error, stack);
    for (final waiter in _waiters) {
      waiter.completer.completeError(error, stack);
    }
    _waiters.clear();
    unawaited(close());
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final waiter in _waiters) {
      waiter.completer.completeError(StateError('Session closed.'));
    }
    _waiters.clear();
    await _subscription.cancel();
    await socket.close(WebSocketStatus.normalClosure);
    // Never await: an unlistened controller's done future never completes.
    unawaited(_events.close());
  }
}

class _Waiter {
  _Waiter(this.test);
  final bool Function(Map<String, dynamic>) test;
  final completer = Completer<Map<String, dynamic>>();
}
