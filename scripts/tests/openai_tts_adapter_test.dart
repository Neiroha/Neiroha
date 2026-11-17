import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';

class _Http {
  final Uri uri;
  final HttpHeaders headers;
  final Map<String, dynamic> body;
  _Http(this.uri, this.headers, this.body);
}

/// Scripted `/audio/speech` server. [respond] writes the reply.
Future<(HttpServer, List<_Http>)> _speechServer(
  void Function(HttpRequest req) respond,
) async {
  final captured = <_Http>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((req) async {
    final text = await utf8.decoder.bind(req).join();
    captured.add(
      _Http(
        req.uri,
        req.headers,
        text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>,
      ),
    );
    respond(req);
    await req.response.close();
  });
  return (server, captured);
}

class _Realtime {
  Uri? uri;
  String? auth;
  final events = <Map<String, dynamic>>[];
}

/// Scripted Realtime WebSocket server. Once `response.create` arrives,
/// [reply] gets the socket to stream server events.
Future<(HttpServer, _Realtime)> _realtimeServer(
  void Function(WebSocket ws) reply,
) async {
  final seen = _Realtime();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((req) async {
    seen
      ..uri = req.uri
      ..auth = req.headers.value('authorization');
    final ws = await WebSocketTransformer.upgrade(req);
    ws.add(jsonEncode({'type': 'session.created', 'session': {}}));
    ws.listen((msg) {
      final event = jsonDecode(msg as String) as Map<String, dynamic>;
      seen.events.add(event);
      if (event['type'] == 'response.create') reply(ws);
    });
  });
  return (server, seen);
}

void main() {
  test(
    'Speech API request carries model, voice, instructions, speed',
    () async {
      final (server, captured) = await _speechServer((req) {
        req.response
          ..headers.contentType = ContentType('application', 'octet-stream')
          ..add([0x49, 0x44, 0x33]);
      });
      final adapter = OpenAiTtsAdapter(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        apiKey: 'sk-test',
        modelName: 'gpt-4o-mini-tts',
      );
      final result = await adapter.synthesize(
        const TtsRequest(
          text: 'Hello there',
          voice: 'ignored',
          presetVoiceName: 'coral',
          voiceInstruction: 'cheerful',
          speed: 1.25,
        ),
      );
      expect(result.audioBytes, [0x49, 0x44, 0x33]);
      // OpenAI answers application/octet-stream; callers key off the type.
      expect(result.contentType, 'audio/mpeg');
      final req = captured.single;
      expect(req.uri.path, '/v1/audio/speech');
      expect(req.headers.value('authorization'), 'Bearer sk-test');
      expect(req.body, {
        'model': 'gpt-4o-mini-tts',
        'input': 'Hello there',
        'voice': 'coral',
        'instructions': 'cheerful',
        'speed': 1.25,
        'response_format': 'mp3',
      });
    },
  );

  test('tts-1 drops instructions; custom voices are sent as {id}', () async {
    final (server, captured) = await _speechServer((req) {
      req.response.add([1, 2, 3]);
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1/',
      apiKey: 'k',
      modelName: 'tts-1-hd',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'x',
        voice: 'x',
        presetVoiceName: 'My narrator [voice_123abc]',
        voiceInstruction: 'whisper',
        responseFormat: 'wav',
      ),
    );
    expect(result.contentType, 'audio/wav');
    final body = captured.single.body;
    expect(body['voice'], {'id': 'voice_123abc'});
    expect(body.containsKey('instructions'), isFalse);
    expect(body.containsKey('speed'), isFalse);
    expect(body['response_format'], 'wav');
  });

  test('Speech API pcm output is wrapped as WAV', () async {
    final (server, _) = await _speechServer((req) {
      req.response.add(List.filled(8, 0));
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'k',
      modelName: 'gpt-4o-mini-tts',
    );
    final result = await adapter.synthesize(
      const TtsRequest(text: 'x', voice: 'marin', responseFormat: 'pcm'),
    );
    expect(result.contentType, 'audio/wav');
    expect(ascii.decode(result.audioBytes.sublist(0, 4)), 'RIFF');
    expect(result.audioBytes.length, 44 + 8);
  });

  test('Speech API errors surface the OpenAI message', () async {
    final (server, _) = await _speechServer((req) {
      req.response
        ..statusCode = 401
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'error': {
              'message': 'Incorrect API key provided',
              'code': 'invalid_api_key',
            },
          }),
        );
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'bad',
      modelName: 'gpt-4o-mini-tts',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'alloy')),
      throwsA(
        predicate(
          (e) =>
              '$e'.contains('HTTP 401') &&
              '$e'.contains('invalid_api_key') &&
              '$e'.contains('Incorrect API key'),
        ),
      ),
    );
  });

  test('Speech API rejects input over 4096 characters locally', () async {
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:1/v1',
      apiKey: 'k',
      modelName: 'gpt-4o-mini-tts',
    );
    await expectLater(
      adapter.synthesize(TtsRequest(text: 'a' * 4097, voice: 'alloy')),
      throwsA(predicate((e) => '$e'.contains('4096'))),
    );
  });

  test('voices a model does not offer fail before any request', () async {
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:1/v1',
      apiKey: 'k',
      modelName: 'gpt-realtime-2.1-mini',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'fable')),
      throwsA(predicate((e) => '$e'.contains('not available'))),
    );
    final legacy = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:1/v1',
      apiKey: 'k',
      modelName: 'tts-1',
    );
    await expectLater(
      legacy.synthesize(const TtsRequest(text: 'a', voice: 'marin')),
      throwsA(predicate((e) => '$e'.contains('not available'))),
    );
  });

  test('Realtime models stream PCM over WebSocket and return WAV', () async {
    final (server, seen) = await _realtimeServer((ws) {
      ws
        ..add(
          jsonEncode({
            'type': 'response.output_audio.delta',
            'delta': base64Encode([1, 0, 2, 0]),
          }),
        )
        ..add(
          jsonEncode({
            'type': 'response.output_audio.delta',
            'delta': base64Encode([3, 0]),
          }),
        )
        ..add(
          jsonEncode({
            'type': 'response.done',
            'response': {'status': 'completed'},
          }),
        );
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'sk-rt',
      modelName: 'gpt-realtime-2.1-mini',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: '你好，世界',
        voice: 'cedar',
        voiceInstruction: 'warm and calm',
        speed: 2.0,
      ),
    );

    expect(seen.uri!.path, '/v1/realtime');
    expect(seen.uri!.queryParameters['model'], 'gpt-realtime-2.1-mini');
    expect(seen.auth, 'Bearer sk-rt');
    expect(seen.events.map((e) => e['type']), [
      'session.update',
      'conversation.item.create',
      'response.create',
    ]);
    final session = seen.events[0]['session'] as Map<String, dynamic>;
    expect(session['type'], 'realtime');
    expect(session['output_modalities'], ['audio']);
    expect(session['instructions'], contains('word for word'));
    expect(session['instructions'], contains('Delivery: warm and calm'));
    expect(session['audio']['input']['turn_detection'], isNull);
    final output = session['audio']['output'] as Map<String, dynamic>;
    expect(output['voice'], 'cedar');
    expect(output['format'], {'type': 'audio/pcm', 'rate': 24000});
    expect(output['speed'], 1.5, reason: 'Realtime speed tops out at 1.5');
    final item = seen.events[1]['item'] as Map<String, dynamic>;
    expect(item['content'], [
      {'type': 'input_text', 'text': '你好，世界'},
    ]);

    expect(result.contentType, 'audio/wav');
    final wav = result.audioBytes;
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    final header = ByteData.sublistView(wav, 0, 44);
    expect(header.getUint32(24, Endian.little), 24000);
    expect(header.getUint32(40, Endian.little), 6);
    expect(wav.sublist(44), [1, 0, 2, 0, 3, 0]);
  });

  test('Realtime error events become exceptions', () async {
    final (server, _) = await _realtimeServer((ws) {
      ws.add(
        jsonEncode({
          'type': 'error',
          'error': {
            'code': 'insufficient_quota',
            'message': 'You exceeded your current quota',
          },
        }),
      );
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'k',
      modelName: 'gpt-realtime-2.1',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'marin')),
      throwsA(predicate((e) => '$e'.contains('insufficient_quota'))),
    );
  });

  test('Realtime failed responses report their status', () async {
    final (server, _) = await _realtimeServer((ws) {
      ws.add(
        jsonEncode({
          'type': 'response.done',
          'response': {
            'status': 'failed',
            'status_details': {'type': 'failed', 'reason': 'server_error'},
          },
        }),
      );
    });
    final adapter = OpenAiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'k',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'marin')),
      throwsA(predicate((e) => '$e'.contains('response failed'))),
    );
  });

  test('helpers: URIs, model routing, voice lists', () async {
    expect(
      OpenAiTtsAdapter.realtimeUri(
        'https://api.openai.com/v1',
        'gpt-realtime-2.1-mini',
      ).toString(),
      'wss://api.openai.com/v1/realtime?model=gpt-realtime-2.1-mini',
    );
    expect(
      OpenAiTtsAdapter.realtimeUri('', 'm').toString(),
      'wss://api.openai.com/v1/realtime?model=m',
    );
    expect(OpenAiTtsAdapter.usesRealtime('gpt-realtime-2.1'), isTrue);
    expect(OpenAiTtsAdapter.usesRealtime('gpt-4o-mini-tts'), isFalse);
    expect(OpenAiTtsAdapter.supportsInstructions('tts-1'), isFalse);
    expect(OpenAiTtsAdapter.supportsInstructions('gpt-realtime-2.1'), isTrue);

    final adapter = OpenAiTtsAdapter(baseUrl: '', apiKey: '');
    final voices = await adapter.getSpeakers();
    expect(voices.take(2), ['marin', 'cedar']);
    expect(voices.toSet(), {
      ...OpenAiTtsAdapter.kSpeechVoices,
      ...OpenAiTtsAdapter.kRealtimeVoices,
    });
    expect(voices.length, voices.toSet().length);
    final models = await adapter.getModels();
    expect(models.first.id, OpenAiTtsAdapter.defaultModel);
  });
}
