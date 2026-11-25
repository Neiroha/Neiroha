import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// The WebSocket transport owns its lifetime and emits raw PCM immediately.
/// File/container assembly belongs to the synthesis session, not this parser.
Stream<TtsEvent> openAiRealtimeStream({
  required Uri uri,
  required String apiKey,
  String apiKeyHeader = 'Authorization',
  required String voiceInstructions,
  required Object voice,
  required String text,
  required double speed,
  required int sampleRate,
  required Duration timeout,
  required TtsCancelToken cancellation,
}) async* {
  cancellation.throwIfCancelled();
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  WebSocket? socket;
  StreamSubscription<dynamic>? subscription;
  final events = StreamController<TtsEvent>(
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
  );
  Timer? deadline;
  var completed = false;
  var receivedBytes = 0;
  var transcript = '';

  void fail(Object error, [StackTrace? stack]) {
    if (completed) return;
    completed = true;
    events.addError(error, stack);
    unawaited(events.close());
    client.close(force: true);
    unawaited(socket?.close());
  }

  final removeCancel = cancellation.onCancel(() {
    // Closing the per-request connection cancels generation even when a
    // response id has not arrived yet. Never reuse this connection for voices.
    fail(const TtsCancelledException());
  });
  deadline = Timer(timeout, () {
    fail(TimeoutException('OpenAI Realtime: synthesis timed out.', timeout));
  });
  try {
    // Attach the connection future before consuming events. Errors enter the
    // controller so cancellation/timeouts can interrupt a pending connection.
    unawaited(() async {
      try {
        final ws = await WebSocket.connect(
          uri.toString(),
          headers: {
            if (apiKey.isNotEmpty)
              apiKeyHeader: apiKeyHeader.toLowerCase() == 'authorization'
                  ? 'Bearer $apiKey'
                  : apiKey,
          },
          customClient: client,
        );
        socket = ws;
        if (completed || cancellation.isCancelled) {
          await ws.close();
          return;
        }
        events.add(
          TtsAudioStarted(
            TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: sampleRate,
              channels: 1,
            ),
          ),
        );
        subscription = ws.listen(
          (message) {
            if (completed || message is! String) return;
            try {
              final decoded = jsonDecode(message);
              if (decoded is! Map) return;
              switch (decoded['type']) {
                case 'response.output_audio.delta':
                  final delta = decoded['delta'];
                  if (delta is String && delta.isNotEmpty) {
                    final bytes = base64Decode(delta);
                    receivedBytes += bytes.length;
                    events.add(TtsAudioChunk(bytes));
                  }
                case 'response.output_audio_transcript.delta':
                  transcript += decoded['delta'] as String? ?? '';
                case 'error':
                  fail(
                    Exception(
                      'OpenAI Realtime: ${jsonEncode(decoded['error'])}',
                    ),
                  );
                case 'response.done':
                  final response = decoded['response'];
                  if (response is! Map || response['status'] != 'completed') {
                    fail(
                      Exception(
                        'OpenAI Realtime: response ${response is Map ? response['status'] : 'unknown'}: ${jsonEncode(response)}',
                      ),
                    );
                  } else if (receivedBytes == 0 || receivedBytes.isOdd) {
                    fail(
                      const FormatException(
                        'OpenAI Realtime: empty or truncated PCM audio.',
                      ),
                    );
                  } else {
                    completed = true;
                    events.add(
                      TtsSynthesisCompleted(
                        usage: response['usage'] is Map
                            ? Map<String, Object?>.from(
                                response['usage'] as Map,
                              )
                            : const {},
                        transcript: transcript.isEmpty ? null : transcript,
                      ),
                    );
                    unawaited(events.close());
                  }
              }
            } catch (error, stack) {
              fail(error, stack);
            }
          },
          onError: fail,
          onDone: () {
            fail(
              const HttpException(
                'OpenAI Realtime: connection closed before the response finished.',
              ),
            );
          },
        );
        for (final event in [
          {
            'type': 'session.update',
            'session': {
              'type': 'realtime',
              'output_modalities': ['audio'],
              'instructions': voiceInstructions,
              'audio': {
                'input': {'turn_detection': null},
                'output': {
                  'format': {'type': 'audio/pcm', 'rate': sampleRate},
                  'voice': voice,
                  if (speed != 1.0) 'speed': speed.clamp(0.25, 1.5),
                },
              },
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': text},
              ],
            },
          },
          {
            'type': 'response.create',
            'response': {
              'output_modalities': ['audio'],
            },
          },
        ]) {
          ws.add(jsonEncode(event));
        }
      } catch (error, stack) {
        fail(error, stack);
      }
    }());
    await for (final event in events.stream) {
      cancellation.throwIfCancelled();
      yield event;
    }
  } finally {
    completed = true;
    deadline.cancel();
    removeCancel();
    await subscription?.cancel();
    await socket?.close(WebSocketStatus.normalClosure);
    client.close(force: true);
    if (!events.isClosed) unawaited(events.close());
  }
}
