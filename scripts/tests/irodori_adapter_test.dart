import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/providers/local/irodori/tts/irodori_adapter.dart';
import 'package:neiroha/data/ai/protocols/http/http_error_message.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/capability.dart';

Future<HttpServer> _serve(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  addTearDown(() => server.close(force: true));
  return server;
}

void _json(HttpResponse response, Object data) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
}

void _audio(HttpResponse response) {
  response.headers.contentType = ContentType('audio', 'wav');
  response.add([82, 73, 70, 70]);
}

void main() {
  test('Irodori exposes TTS models and registered voice sets', () async {
    final paths = <String>[];
    String? auth;
    Map<String, dynamic>? speech;
    final server = await _serve((request) async {
      paths.add(request.uri.path);
      auth = request.headers.value(HttpHeaders.authorizationHeader);
      switch (request.uri.path) {
        case '/irodori/health':
          _json(request.response, {'backend': 'irodori', 'status': 'ok'});
        case '/irodori/v1/models':
          _json(request.response, {
            'data': [
              {'id': 'azurlane', 'name': 'Azur Lane'},
            ],
          });
        case '/irodori/v1/audio/voices':
          _json(request.response, {
            'data': [
              {'id': 'default', 'name': 'RF', 'model': 'default'},
              {'id': 'al-ship-30505-ja', 'name': '长门', 'model': 'azurlane'},
            ],
          });
        case '/irodori/v1/audio/speech':
          speech =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          _audio(request.response);
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    final provider = db.TtsProvider(
      id: 'irodori',
      name: 'Irodori',
      adapterType: 'irodori',
      baseUrl: 'http://127.0.0.1:${server.port}/irodori/v1/',
      apiKey: 'test-key',
      defaultModelName: 'default',
      enabled: true,
      position: 0,
      maxConcurrency: 1,
    );
    final adapter =
        createAdapter(provider, modelName: 'azurlane') as IrodoriAdapter;
    expect(connectionForProvider(provider).capabilities, {AiCapability.tts});
    expect(adapter.supportsStreaming, isFalse);
    expect(await adapter.healthCheck(), isTrue);
    expect((await adapter.getModels()).single.id, 'azurlane');
    expect(await adapter.getSpeakers(), contains('长门 [al-ship-30505-ja]'));
    expect(await adapter.getSpeakersForVoiceSet('azurlane'), [
      '长门 [al-ship-30505-ja]',
    ]);
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'おかえりなさい。',
        voice: 'display name',
        presetVoiceName: '长门 [al-ship-30505-ja]',
        speed: 1.1,
      ),
    );
    expect(result.contentType, 'audio/wav');
    expect(auth, 'Bearer test-key');
    expect(paths.last, '/irodori/v1/audio/speech');
    expect(speech, {
      'model': 'azurlane',
      'voice': 'al-ship-30505-ja',
      'input': 'おかえりなさい。',
      'speed': 1.1,
      'response_format': 'wav',
    });
  });

  test(
    'Irodori uploads reference audio and chooses the matching preset',
    () async {
      final bodies = <String>[];
      final server = await _serve((request) async {
        if (request.uri.path == '/v1/audio/voices') {
          _json(request.response, {
            'data': [
              {'id': 'saved-1', 'model': 'local', 'model_preset': 'meanflow'},
            ],
          });
        } else if (request.uri.path == '/api/irodori/clone') {
          expect(request.headers.contentType?.mimeType, 'multipart/form-data');
          bodies.add(await utf8.decoder.bind(request).join());
          _audio(request.response);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      final directory = await Directory.systemTemp.createTemp('irodori_test');
      final reference = await File(
        '${directory.path}/reference.wav',
      ).writeAsString('reference-data');
      addTearDown(() async {
        await reference.delete();
        await directory.delete();
      });

      for (final (model, voice, preset) in [
        ('azurlane', 'default', 'azurlane-lora'),
        ('local', 'Saved voice [saved-1]', 'meanflow'),
      ]) {
        final adapter = IrodoriAdapter(
          baseUrl: 'http://127.0.0.1:${server.port}',
          apiKey: '',
          modelName: model,
        );
        final result = await adapter.synthesize(
          TtsRequest(
            text: 'reference test',
            voice: voice,
            refAudioPath: reference.path,
            voiceInstruction: 'quietly',
          ),
        );
        expect(result.audioBytes, [82, 73, 70, 70]);
        expect(bodies.last, contains('name="model_preset"\r\n\r\n$preset'));
        expect(bodies.last, contains('name="caption"\r\n\r\nquietly'));
        expect(
          bodies.last,
          contains('name="reference"; filename="reference.wav"'),
        );
        expect(bodies.last, contains('reference-data'));
      }
      expect(bodies, hasLength(2));
    },
  );

  test('Irodori surfaces structured backend errors', () async {
    final server = await _serve((request) async {
      await request.drain<void>();
      request.response.statusCode = HttpStatus.notFound;
      _json(request.response, {
        'error': {'message': 'Voice is unavailable.'},
      });
      await request.response.close();
    });
    final adapter = IrodoriAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    await expectLater(
      adapter.synthesize(const TtsRequest(text: 'test', voice: 'missing')),
      throwsA(
        isA<TtsHttpException>()
            .having((error) => error.statusCode, 'status', 404)
            .having(
              (error) => error.message,
              'message',
              'Voice is unavailable.',
            ),
      ),
    );
  });
}
