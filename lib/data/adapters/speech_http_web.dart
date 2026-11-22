import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:web/web.dart' as web;

import 'speech_http_response.dart';

Future<SpeechHttpResponse> postSpeech(
  Uri uri,
  Map<String, String> headers,
  Object body,
  TtsCancelToken cancellation,
  Duration timeout,
) async {
  final controller = web.AbortController();
  final remove = cancellation.onCancel(() => controller.abort());
  final requestHeaders = web.Headers()..set('Content-Type', 'application/json');
  headers.forEach((name, value) => requestHeaders.set(name, value));
  void close() {
    remove();
    controller.abort();
  }

  try {
    cancellation.throwIfCancelled();
    final response = await _fetch(uri, requestHeaders, body, controller.signal);

    if (!response.ok) {
      throw StateError('Speech request failed (${response.status})');
    }
    final stream = response.body;
    if (stream == null) throw const FormatException('Speech returned no body.');
    return (
      header: (name) => response.headers.get(name),
      chunks: _readChunks(stream, timeout),
      close: close,
    );
  } catch (_) {
    close();
    cancellation.throwIfCancelled();
    rethrow;
  }
}

Future<web.Response> _fetch(
  Uri uri,
  web.Headers headers,
  Object body,
  web.AbortSignal signal,
) async {
  try {
    return await web.window
        .fetch(
          uri.toString().toJS,
          web.RequestInit(
            method: 'POST',
            headers: headers,
            body: (body is String ? body : jsonEncode(body)).toJS,
            signal: signal,
            redirect: 'error',
            credentials: 'omit',
            cache: 'no-store',
          ),
        )
        .toDart
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    rethrow;
  } catch (_) {
    throw const BrowserSpeechConnectionException();
  }
}

Stream<Uint8List> _readChunks(
  web.ReadableStream stream,
  Duration timeout,
) async* {
  final reader = web.ReadableStreamDefaultReader(stream);
  try {
    while (true) {
      final result = await reader.read().toDart.timeout(timeout);
      if (result.done) break;
      yield (result.value as JSUint8Array).toDart;
    }
  } finally {
    reader.releaseLock();
  }
}
