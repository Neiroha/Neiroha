import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const clientClosedContextKey = 'neiroha.io.clientClosed';
const streamingResponseContextKey = 'neiroha.io.streaming';

class TrackedHttpServer {
  TrackedHttpServer(this._server);
  final HttpServer _server;
  final _streams = <Socket, void Function()>{};
  bool _closing = false;
  int get port => _server.port;
  Future<void> close({bool force = false}) async {
    _closing = true;
    for (final entry in _streams.entries.toList()) {
      entry.value();
      entry.key.destroy();
    }
    _streams.clear();
    await _server.close(force: force);
  }
}

/// Retains Shelf routing, authentication, limits and CORS. Only an explicitly
/// marked audio response takes over its socket after middleware has completed.
Future<TrackedHttpServer> serveTrackedHttp(
  Handler handler,
  Object address,
  int port,
) async {
  final server = await HttpServer.bind(address, port);
  final tracked = TrackedHttpServer(server);
  server.listen((native) {
    final closed = Completer<void>();
    var streaming = false;
    void complete() {
      if (!closed.isCompleted) closed.complete();
    }

    unawaited(
      native.response.done.then(
        (_) {
          if (!streaming) complete();
        },
        onError: (Object _) {
          if (!streaming) complete();
        },
      ),
    );
    unawaited(
      shelf_io
          .handleRequest(native, (request) async {
            final response = await handler(
              request.change(context: {clientClosedContextKey: closed.future}),
            );
            if (response.context[streamingResponseContextKey] != true) {
              return response;
            }
            // The SDK pauses HTTP reads during an outstanding response. Its done
            // future cannot detect disconnect during a stalled model. Shelf's hijack
            // channel exposes socket EOF; Connection: close scopes it to this request.
            streaming = true;
            request.hijack((channel) async {
              final socket = channel.sink as Socket;
              if (tracked._closing) {
                complete();
                socket.destroy();
                return;
              }
              tracked._streams[socket] = complete;
              // IOSink reports a failed source through both addStream and
              // done. Observe done immediately, including a disconnect race.
              unawaited(
                socket.done.then<void>(
                  (_) {},
                  onError: (Object _) => complete(),
                ),
              );
              final incoming = channel.stream.listen(
                (_) {},
                onDone: complete,
                onError: (Object _) => complete(),
                cancelOnError: true,
              );
              try {
                final headers = StringBuffer(
                  'HTTP/1.1 ${response.statusCode} OK\r\nConnection: close\r\nTransfer-Encoding: chunked\r\n',
                );
                for (final entry in response.headersAll.entries) {
                  if ({
                    'content-length',
                    'transfer-encoding',
                    'connection',
                  }.contains(entry.key.toLowerCase())) {
                    continue;
                  }
                  if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(entry.key)) {
                    throw const FormatException('Invalid stream header.');
                  }
                  for (final value in entry.value) {
                    if (value.contains('\r') || value.contains('\n')) {
                      throw const FormatException('Invalid stream header.');
                    }
                    headers.write('${entry.key}: $value\r\n');
                  }
                }
                headers.write('\r\n');
                channel.sink.add(latin1.encode(headers.toString()));
                await channel.sink.addStream(_chunked(response.read()));
              } catch (_) {
                // Client disconnect aborts the body without a synthetic success tail.
              } finally {
                complete();
                tracked._streams.remove(socket);
                await incoming.cancel();
                try {
                  await channel.sink.close();
                } catch (_) {}
              }
            });
          })
          .catchError((Object _, StackTrace stack) {
            complete();
          }),
    );
  });
  return tracked;
}

/// The terminating chunk is emitted only after normal completion. A synthesis
/// error closes a truncated HTTP body, so clients can distinguish it from EOF.
Stream<List<int>> _chunked(Stream<List<int>> source) async* {
  await for (final bytes in source) {
    if (bytes.isEmpty) continue;
    yield ascii.encode('${bytes.length.toRadixString(16)}\r\n');
    yield bytes;
    yield const [13, 10];
  }
  yield const [48, 13, 10, 13, 10];
}
