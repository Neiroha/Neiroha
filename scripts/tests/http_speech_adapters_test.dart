import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/azure_tts_adapter.dart';
import 'package:neiroha/data/adapters/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/adapters/elevenlabs_adapter.dart';
import 'package:neiroha/data/adapters/gemini_tts_adapter.dart';
import 'package:neiroha/data/adapters/minimax_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/server/speech_stream_response.dart';

const _pcm = TtsRequest(
  text: 'A <voice> test',
  voice: 'fixture',
  presetVoiceName: 'Fixture [fixture]',
  responseFormat: 'pcm',
);
const _deadline = Duration(seconds: 5);

void main() {
  final eleven = _Route(
    name: 'ElevenLabs',
    path: '/v1/text-to-speech/fixture/stream',
    adapter: (url) => ElevenLabsAdapter(baseUrl: url, apiKey: 'fixture'),
    verify: (uri, headers, body) {
      expect(uri.queryParameters['output_format'], 'pcm_24000');
      expect(headers.value('xi-api-key'), 'fixture');
      expect(jsonDecode(body)['model_id'], 'eleven_v4');
    },
  );
  final azure = _Route(
    name: 'Azure',
    path: '/cognitiveservices/v1',
    adapter: (url) => AzureTtsAdapter(baseUrl: url, apiKey: 'fixture'),
    verify: (uri, headers, body) {
      expect(headers.contentType?.mimeType, 'application/ssml+xml');
      expect(
        headers.value('x-microsoft-outputformat'),
        'raw-24khz-16bit-mono-pcm',
      );
      expect(body, contains('A &lt;voice&gt; test'));
    },
  );
  final minimax = _Route(
    name: 'MiniMax',
    path: '/v1/t2a_v2',
    adapter: (url) => MiniMaxTtsAdapter(baseUrl: '$url/v1', apiKey: 'fixture'),
    verify: (uri, headers, body) {
      final json = jsonDecode(body);
      expect(json['stream'], isTrue);
      expect(json['stream_options']['exclude_aggregated_audio'], isTrue);
      expect(json['audio_setting'], {
        'sample_rate': 32000,
        'format': 'pcm',
        'channel': 1,
      });
    },
    parts: [
      '{"data":{"status":1,"audio":"0100"}}',
      '{"data":{"status":1,"audio":"0200"}}',
    ],
    end: '{"data":{"status":2,"audio":"01000200"}}',
    rate: 32000,
  );
  final gemini = _Route(
    name: 'Gemini',
    path: '/v1beta/interactions',
    adapter: (url) => GeminiTtsAdapter(baseUrl: url, apiKey: 'fixture'),
    verify: (uri, headers, body) {
      final json = jsonDecode(body);
      expect(json['stream'], isTrue);
      expect(json['response_format']['mime_type'], 'audio/l16');
      expect(headers.value('x-goog-api-key'), 'fixture');
    },
    parts: [
      '{"event_type":"step.delta","delta":{"type":"audio","data":"AQA="}}',
      '{"event_type":"step.delta","delta":{"type":"audio","data":"AgA="}}',
    ],
    end:
        '{"event_type":"interaction.completed","interaction":{"status":"completed"}}',
  );
  final mimo = _Route(
    name: 'MiMo',
    path: '/v1/chat/completions',
    adapter: (url) => ChatCompletionsTtsAdapter(
      baseUrl: '$url/v1',
      apiKey: 'fixture',
      modelName: 'mimo-v2.5-tts',
    ),
    verify: (uri, headers, body) {
      final json = jsonDecode(body);
      expect(json['stream'], isTrue);
      expect(json['audio'], {'format': 'pcm16', 'voice': _pcm.presetVoiceName});
      expect(headers.value('api-key'), 'fixture');
    },
    parts: [
      '{"choices":[{"delta":{"audio":{"data":"AQA="}}}]}',
      '{"choices":[{"delta":{"audio":{"data":"AgA="}}}]}',
    ],
    end: '[DONE]',
  );

  for (final route in [eleven, azure, minimax, gemini, mimo]) {
    test('${route.name} emits PCM before the response completes', () async {
      final fixture = await _open(route);
      final adapter = route.adapter(fixture.url);
      expect(adapter.supportsStreaming, isTrue);
      final events = StreamIterator(
        adapter.synthesizeStream(_pcm, cancellation: TtsCancelToken()),
      );
      addTearDown(events.cancel);
      expect(await events.moveNext().timeout(_deadline), isTrue);
      final format = (events.current as TtsAudioStarted).format;
      expect(format.encoding, AudioEncoding.pcmS16le);
      expect(format.sampleRate, route.rate);
      expect(format.channels, 1);
      expect(await events.moveNext().timeout(_deadline), isTrue);
      expect((events.current as TtsAudioChunk).bytes, [1, 0]);
      final request = await fixture.request.future.timeout(_deadline);
      expect(request.uri.path, route.path);
      route.verify(request.uri, request.headers, request.body);
      expect(fixture.release.isCompleted, isFalse);
      fixture.release.complete();
      expect(await events.moveNext().timeout(_deadline), isTrue);
      expect((events.current as TtsAudioChunk).bytes, [2, 0]);
      expect(await events.moveNext().timeout(_deadline), isTrue);
      expect(events.current, isA<TtsSynthesisCompleted>());
      expect(await events.moveNext().timeout(_deadline), isFalse);
    });

    test('${route.name} aborts a waiting HTTP response', () async {
      final fixture = await _open(route, trackDisconnect: true);
      final cancellation = TtsCancelToken();
      final events = StreamIterator(
        route
            .adapter(fixture.url)
            .synthesizeStream(_pcm, cancellation: cancellation),
      );
      addTearDown(events.cancel);
      expect(await events.moveNext().timeout(_deadline), isTrue);
      expect(await events.moveNext().timeout(_deadline), isTrue);
      final failed = expectLater(
        events.moveNext().timeout(_deadline),
        throwsA(isA<TtsCancelledException>()),
      );
      cancellation.cancel();
      await failed;
      await fixture.disconnected.future.timeout(_deadline);
    });
  }

  for (final route in [minimax, gemini, mimo]) {
    test('${route.name} rejects EOF before successful completion', () async {
      final fixture = await _open(route, truncate: true);
      fixture.release.complete();
      await expectLater(
        route
            .adapter(fixture.url)
            .synthesizeStream(_pcm, cancellation: TtsCancelToken()),
        emitsInOrder([
          isA<TtsAudioStarted>(),
          isA<TtsAudioChunk>(),
          emitsError(isA<FormatException>()),
        ]),
      );
    });
  }

  test(
    'local speech API sends MiniMax PCM before the upstream response ends',
    () async {
      final fixture = await _open(minimax);
      final response = await streamSpeechResponse(
        provider: TtsProvider(
          id: 'minimax-loopback',
          name: 'MiniMax fixture',
          adapterType: 'minimaxTts',
          baseUrl: fixture.url,
          apiKey: 'fixture',
          defaultModelName: 'speech-2.8-hd',
          enabled: true,
          position: 0,
          maxConcurrency: 1,
        ),
        request: _pcm,
      ).timeout(_deadline);
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'audio/pcm');
      expect(response.headers['x-audio-sample-rate'], '32000');
      final audio = StreamIterator(response.read());
      addTearDown(audio.cancel);
      expect(await audio.moveNext().timeout(_deadline), isTrue);
      expect(audio.current, [1, 0]);
      expect(fixture.release.isCompleted, isFalse);
      fixture.release.complete();
      expect(await audio.moveNext().timeout(_deadline), isTrue);
      expect(audio.current, [2, 0]);
      expect(await audio.moveNext().timeout(_deadline), isFalse);
    },
  );
}

class _Route {
  const _Route({
    required this.name,
    required this.path,
    required this.adapter,
    required this.verify,
    this.parts,
    this.end,
    this.rate = 24000,
  });

  final String name;
  final String path;
  final TtsAdapter Function(String) adapter;
  final void Function(Uri, HttpHeaders, String) verify;
  final List<String>? parts;
  final String? end;
  final int rate;
}

typedef _WireRequest = ({Uri uri, HttpHeaders headers, String body});

Future<
  ({
    String url,
    Completer<void> release,
    Completer<void> disconnected,
    Completer<_WireRequest> request,
  })
>
_open(
  _Route route, {
  bool truncate = false,
  bool trackDisconnect = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final release = Completer<void>();
  final disconnected = Completer<void>();
  final request = Completer<_WireRequest>();
  addTearDown(() async {
    if (!release.isCompleted) release.complete();
    await server.close(force: true);
  });
  server.listen((incoming) async {
    final response = incoming.response;
    try {
      request.complete((
        uri: incoming.uri,
        headers: incoming.headers,
        body: await utf8.decoder.bind(incoming).join(),
      ));
      if (trackDisconnect) {
        await _waitForPeer(response, route.parts?.first, disconnected, release);
        return;
      }
      unawaited(response.done.then<void>((_) {}, onError: (Object _) {}));
      response.bufferOutput = false;
      final parts = route.parts;
      if (parts == null) {
        response.headers.set('content-type', 'application/octet-stream');
        response.add([1, 0]);
      } else {
        response.headers.set(
          'content-type',
          'text/event-stream; charset=utf-8',
        );
        final first = parts.first;
        response.add(
          utf8.encode('event: message\r\ndata: ${first.substring(0, 8)}'),
        );
        await response.flush();
        response.add(utf8.encode('${first.substring(8)}\r\n\r\n'));
      }
      await response.flush();
      await release.future;
      if (!truncate) {
        if (parts == null) {
          response.add([2, 0]);
        } else {
          response.add(
            utf8.encode('data: ${parts.last}\n\ndata: ${route.end}\n\n'),
          );
        }
      }
      await response.close();
    } catch (_) {
      // Tests intentionally abort the response with its body still open.
    }
  });
  return (
    url: 'http://127.0.0.1:${server.port}',
    release: release,
    disconnected: disconnected,
    request: request,
  );
}

Future<void> _waitForPeer(
  HttpResponse response,
  String? firstEvent,
  Completer<void> disconnected,
  Completer<void> release,
) async {
  // A detached socket observes peer closure while the response is idle.
  final socket = await response.detachSocket(writeHeaders: false);
  final mime = firstEvent == null
      ? 'application/octet-stream'
      : 'text/event-stream';
  final bytes = firstEvent == null
      ? [1, 0]
      : utf8.encode('data: $firstEvent\n\n');
  void closed() {
    if (!disconnected.isCompleted) disconnected.complete();
  }

  socket.listen((_) {}, onDone: closed, onError: (Object _) => closed());
  try {
    socket.write(
      'HTTP/1.1 200 OK\r\nContent-Type: $mime\r\n'
      'Transfer-Encoding: chunked\r\n\r\n'
      '${bytes.length.toRadixString(16)}\r\n',
    );
    socket.add(bytes);
    socket.write('\r\n');
    await socket.flush();
    await release.future;
  } finally {
    socket.destroy();
  }
}
