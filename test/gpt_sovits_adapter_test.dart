import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/gpt_sovits_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';

void main() {
  test('model discovery uses OpenAI voice-set models', () async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final handled = Completer<void>();
    server.listen((request) async {
      paths.add(request.uri.path);
      if (request.uri.path == '/v1/models') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'object': 'list',
              'data': [
                {'id': 'default', 'name': 'Default'},
              ],
            }),
          );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
      if (!handled.isCompleted) handled.complete();
    });

    final adapter = GptSovitsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    final models = await adapter.getModels();

    await handled.future.timeout(const Duration(seconds: 2));
    expect(paths, ['/v1/models']);
    expect(models, hasLength(1));
    expect(models.single.id, 'default');
    expect(models.single.name, 'Default');
  });

  test('speaker discovery prefers the Neiroha native route', () async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final handled = Completer<void>();
    server.listen((request) async {
      paths.add(request.uri.path);
      if (request.uri.path == '/api/gpt-sovits/voices') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'object': 'list',
              'data': [
                {'id': 'genshin-keqing', 'name': 'Keqing'},
              ],
            }),
          );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
      if (!handled.isCompleted) handled.complete();
    });

    final adapter = GptSovitsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    final voices = await adapter.getSpeakers();

    await handled.future.timeout(const Duration(seconds: 2));
    expect(paths, ['/api/gpt-sovits/voices']);
    expect(voices, ['genshin-keqing']);
  });

  test('clone synthesis prefers the Neiroha native route', () async {
    final requests = <_CapturedRequest>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final handled = Completer<void>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add(_CapturedRequest(request.method, request.uri.path, body));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('audio', 'wav')
        ..add([1, 2, 3]);
      await request.response.close();
      if (!handled.isCompleted) handled.complete();
    });

    final adapter = GptSovitsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'hello',
        voice: 'clone',
        refAudioPath: 'D:/voices/ref.wav',
        promptText: 'reference text',
      ),
    );

    await handled.future.timeout(const Duration(seconds: 2));
    expect(result.audioBytes, [1, 2, 3]);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/api/gpt-sovits/clone');

    final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(payload['model'], 'default');
    expect(payload['input'], 'hello');
    expect(payload['ref_audio_path'], 'D:/voices/ref.wav');
    expect(payload['prompt_text'], 'reference text');
  });

  test(
    'language modelName maps to text_lang without replacing voice set model',
    () async {
      final requests = <_CapturedRequest>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final handled = Completer<void>();
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(_CapturedRequest(request.method, request.uri.path, body));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('audio', 'wav')
          ..add([7, 8, 9]);
        await request.response.close();
        if (!handled.isCompleted) handled.complete();
      });

      final adapter = GptSovitsAdapter(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: '',
        modelName: 'zh',
      );
      final result = await adapter.synthesize(
        const TtsRequest(text: '你好', voice: 'genshin-keqing'),
      );

      await handled.future.timeout(const Duration(seconds: 2));
      expect(result.audioBytes, [7, 8, 9]);
      expect(requests.single.path, '/v1/audio/speech');

      final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(payload['model'], 'default');
      expect(payload['text_lang'], 'zh');
      expect(payload['voice'], 'genshin-keqing');
    },
  );

  test('clone synthesis falls back to the legacy native route', () async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final handled = Completer<void>();
    server.listen((request) async {
      paths.add(request.uri.path);
      await utf8.decoder.bind(request).join();
      if (request.uri.path == '/api/gpt-sovits/clone') {
        request.response.statusCode = HttpStatus.notFound;
      } else if (request.uri.path == '/gpt-sovits/clone') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('audio', 'wav')
          ..add([4, 5, 6]);
      }
      await request.response.close();
      if (paths.length >= 2 && !handled.isCompleted) handled.complete();
    });

    final adapter = GptSovitsAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    final result = await adapter.synthesize(
      const TtsRequest(
        text: 'hello',
        voice: 'clone',
        refAudioPath: 'D:/voices/ref.wav',
      ),
    );

    await handled.future.timeout(const Duration(seconds: 2));
    expect(result.audioBytes, [4, 5, 6]);
    expect(paths, ['/api/gpt-sovits/clone', '/gpt-sovits/clone']);
  });
}

class _CapturedRequest {
  final String method;
  final String path;
  final String body;

  const _CapturedRequest(this.method, this.path, this.body);
}
