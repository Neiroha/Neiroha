import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/elevenlabs_adapter.dart';
import 'package:neiroha/data/adapters/gemini_tts_adapter.dart';
import 'package:neiroha/data/adapters/index_tts_adapter.dart';
import 'package:neiroha/data/adapters/minimax_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';

/// Tiny scripted HTTP server: [handler] gets the request + body and writes
/// the response itself.
Future<(HttpServer, List<_Captured>)> _serve(
  Future<void> Function(HttpRequest req, String body) handler,
) async {
  final captured = <_Captured>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((req) async {
    final bytes = await req.fold<List<int>>([], (a, b) => a..addAll(b));
    final body = utf8.decode(bytes, allowMalformed: true);
    captured.add(_Captured(req.method, req.uri, req.headers, body));
    await handler(req, body);
    await req.response.close();
  });
  return (server, captured);
}

class _Captured {
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  _Captured(this.method, this.uri, this.headers, this.body);
}

void _json(HttpRequest req, Object body) {
  req.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
}

void main() {
  test('voice labels round-trip to ids', () {
    expect(voiceIdFromLabel('Rachel [21m00Tcm4]'), '21m00Tcm4');
    expect(voiceIdFromLabel('male-qn-qingse'), 'male-qn-qingse');
    expect(voiceLabel('Kore', 'Kore'), 'Kore');
    expect(voiceLabel('Rachel', 'abc'), 'Rachel [abc]');
  });

  test('MiniMax voice ids satisfy the upstream format', () {
    final id = MiniMaxTtsAdapter.makeVoiceId('柯南 Conan!');
    expect(id, matches(RegExp(r'^[A-Za-z][A-Za-z0-9_-]{7,255}$')));
    expect(id.endsWith('_') || id.endsWith('-'), isFalse);
  });

  test('MiniMax decodes hex audio and forwards emotion', () async {
    final (server, captured) = await _serve((req, body) async {
      _json(req, {
        'data': {'audio': '494433', 'status': 2},
        'base_resp': {'status_code': 0, 'status_msg': 'success'},
      });
    });
    final adapter = MiniMaxTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: 'k',
      modelName: 'speech-2.8-turbo',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: '你好',
        voice: 'x',
        presetVoiceName: 'Narrator [male-qn-qingse]',
        voiceInstruction: 'Happy',
      ),
    );
    expect(result.audioBytes, [0x49, 0x44, 0x33]);
    expect(captured.single.uri.path, '/v1/t2a_v2');
    expect(captured.single.headers.value('authorization'), 'Bearer k');
    final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
    expect(body['model'], 'speech-2.8-turbo');
    expect(body['voice_setting']['voice_id'], 'male-qn-qingse');
    expect(body['voice_setting']['emotion'], 'happy');
  });

  test('MiniMax surfaces base_resp errors', () async {
    final (server, _) = await _serve((req, body) async {
      _json(req, {
        'base_resp': {'status_code': 1004, 'status_msg': 'auth failed'},
      });
    });
    final adapter = MiniMaxTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'bad',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'v')),
      throwsA(predicate((e) => '$e'.contains('1004'))),
    );
  });

  test('ElevenLabs posts to the voice id parsed from the label', () async {
    final (server, captured) = await _serve((req, body) async {
      req.response
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..add([1, 2, 3]);
    });
    final adapter = ElevenLabsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'xi',
      modelName: 'eleven_v3',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'Hello',
        voice: 'ignored',
        presetVoiceName: 'Rachel [abc123]',
        voiceInstruction: 'whispers',
      ),
    );
    expect(result.audioBytes, [1, 2, 3]);
    expect(result.contentType, 'audio/mpeg');
    final req = captured.single;
    expect(req.uri.path, '/v1/text-to-speech/abc123');
    expect(req.uri.queryParameters['output_format'], 'mp3_44100_128');
    expect(req.headers.value('xi-api-key'), 'xi');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['model_id'], 'eleven_v3');
    expect(body['text'], '[whispers] Hello');
  });

  test('Gemini 3.8 uses the Interactions API and passes WAV through', () async {
    final wav = [0x52, 0x49, 0x46, 0x46, ...List.filled(40, 0)];
    final (server, captured) = await _serve((req, body) async {
      _json(req, {
        'steps': [
          {
            'type': 'model_output',
            'content': [
              {'type': 'audio', 'data': base64Encode(wav)},
            ],
          },
        ],
      });
    });
    final adapter = GeminiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'g',
      modelName: 'gemini-3.8-flash-tts',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'Hi',
        voice: 'x',
        presetVoiceName: 'Puck',
        voiceInstruction: 'cheerful',
      ),
    );
    expect(result.audioBytes, wav);
    expect(captured.single.uri.path, '/v1beta/interactions');
    final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
    expect(body['generation_config']['speech_config'][0]['voice'], 'Puck');
    final content = body['input'][0]['content'][0] as Map<String, dynamic>;
    expect(content['text'], 'Hi');
    expect(content['annotations'][0]['style'], 'cheerful');
  });

  test('Gemini legacy models keep using generateContent', () async {
    final (server, captured) = await _serve((req, body) async {
      _json(req, {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': 'audio/L16;rate=24000',
                    'data': base64Encode([0, 0, 1, 0]),
                  },
                },
              ],
            },
          },
        ],
      });
    });
    final adapter = GeminiTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'g',
      modelName: 'gemini-2.5-flash-preview-tts',
    );
    final result = await adapter.synthesize(
      const TtsRequest(text: 'Hi', voice: 'x'),
    );
    expect(
      captured.single.uri.path,
      '/v1beta/models/gemini-2.5-flash-preview-tts:generateContent',
    );
    expect(ascii.decode(result.audioBytes.sublist(0, 4)), 'RIFF');
    expect(result.audioBytes.length, 44 + 4);
  });

  test('IndexTTS drives the WebUI /gen_single Gradio endpoint', () async {
    final tmp = await Directory.systemTemp.createTemp('neiroha_idx');
    addTearDown(() => tmp.delete(recursive: true));
    final ref = File('${tmp.path}/ref.wav')..writeAsBytesSync([9, 9, 9]);

    List<dynamic>? callData;
    final (server, captured) = await _serve((req, body) async {
      final path = req.uri.path;
      if (path == '/gradio_api/info') {
        _json(req, {
          'named_endpoints': {
            '/gen_single': {
              'parameters': [
                {
                  'parameter_name': 'emo_control_method',
                  'parameter_has_default': true,
                  'parameter_default': 'A',
                  'type': {
                    'enum': ['A', 'B', 'C', 'D'],
                  },
                },
                {'parameter_name': 'prompt'},
                {'parameter_name': 'text'},
                {
                  'parameter_name': 'lang_choice',
                  'parameter_has_default': true,
                  'parameter_default': 'ZH',
                },
                {
                  'parameter_name': 'emo_weight',
                  'parameter_has_default': true,
                  'parameter_default': 0.65,
                },
                {'parameter_name': 'emo_text'},
                {'parameter_name': 'duration_factor'},
                {
                  'parameter_name': 'param_18',
                  'parameter_has_default': true,
                  'parameter_default': 0.8,
                },
              ],
            },
          },
        });
      } else if (path == '/gradio_api/upload') {
        _json(req, ['/srv/tmp/ref.wav']);
      } else if (path == '/gradio_api/call/gen_single' &&
          req.method == 'POST') {
        callData = (jsonDecode(body) as Map)['data'] as List;
        _json(req, {'event_id': 'ev1'});
      } else if (path == '/gradio_api/call/gen_single/ev1') {
        req.response
          ..headers.contentType = ContentType('text', 'event-stream')
          ..write('event: generating\ndata: null\n\n')
          ..write(
            'event: complete\ndata: [{"__type__": "update", "visible": true, '
            '"value": {"path": "/srv/out/spk_1.wav", "url": null}}]\n\n',
          );
      } else if (path.startsWith('/gradio_api/file=')) {
        req.response.add([7, 7, 7]);
      } else {
        req.response.statusCode = 404;
      }
    });

    final adapter = IndexTtsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
      modelName: 'auto',
    );
    final result = await adapter.synthesize(
      TtsRequest(
        text: 'こんにちは',
        voice: 'v',
        speed: 2.0,
        refAudioPath: ref.path,
        voiceInstruction: 'sad and quiet',
      ),
    );
    expect(result.audioBytes, [7, 7, 7]);
    expect(callData, isNotNull);
    expect(callData![0], 'D'); // emotion-text mode chosen by enum index 3
    expect((callData![1] as Map)['path'], '/srv/tmp/ref.wav');
    expect(callData![2], 'こんにちは');
    expect(callData![3], 'JA'); // auto-detected from kana
    expect(callData![4], 0.65); // untouched defaults survive
    expect(callData![5], 'sad and quiet');
    expect(callData![6], 0.5); // speed 2.0 → duration factor 0.5
    expect(callData![7], 0.8);
    expect(captured.last.uri.path, '/gradio_api/file=/srv/out/spk_1.wav');
  });

  test('IndexTTS requires reference audio', () async {
    final adapter = IndexTtsAdapter(baseUrl: '', apiKey: '');
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'a', voice: 'v')),
      throwsException,
    );
  });
}
