import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';

void main() {
  test('synthesis prefers the Neiroha native JSON endpoint', () async {
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
        ..add([0, 1, 2]);
      await request.response.close();
      if (!handled.isCompleted) handled.complete();
    });

    final adapter = VoxCpm2NativeAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
      modelName: 'design',
    );
    final result = await adapter.synthesize(
      const TtsRequest(text: 'hello', voice: 'default'),
    );

    await handled.future.timeout(const Duration(seconds: 2));
    expect(result.audioBytes, [0, 1, 2]);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/api/voxcpm/tts');

    final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(payload['model'], 'default');
    expect(payload['mode'], 'design');
    expect(payload['text'], 'hello');
  });

  test('voice discovery falls back to the legacy registry endpoint', () async {
    final paths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final handled = Completer<void>();
    server.listen((request) async {
      paths.add(request.uri.path);
      if (request.uri.path == '/api/voxcpm/voices') {
        request.response.statusCode = HttpStatus.notFound;
      } else if (request.uri.path == '/voxcpm/voices') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'id': 'voice-a', 'display_name': 'Voice A', 'mode': 'clone'},
              ],
            }),
          );
      }
      await request.response.close();
      if (paths.length >= 2 && !handled.isCompleted) handled.complete();
    });

    final adapter = VoxCpm2NativeAdapter(
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: '',
    );
    final voices = await adapter.getVoices();

    await handled.future.timeout(const Duration(seconds: 2));
    expect(paths, ['/api/voxcpm/voices', '/voxcpm/voices']);
    expect(voices, hasLength(1));
    expect(voices.single.id, 'voice-a');
    expect(voices.single.displayName, 'Voice A');
    expect(voices.single.modeHint, 'clone');
  });

  test(
    'upload fallback rebuilds multipart data for legacy launchers',
    () async {
      final temp = await File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}voxcpm-ref.wav',
      ).writeAsBytes([82, 73, 70, 70]);
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync();
      });

      final paths = <String>[];
      final bodies = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      final handled = Completer<void>();
      server.listen((request) async {
        paths.add(request.uri.path);
        bodies.add(await utf8.decoder.bind(request).join());
        if (request.uri.path == '/api/voxcpm/tts/upload') {
          request.response.statusCode = HttpStatus.notFound;
        } else if (request.uri.path == '/voxcpm/speech/upload') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType('audio', 'wav')
            ..add([3, 4, 5]);
        }
        await request.response.close();
        if (paths.length >= 2 && !handled.isCompleted) handled.complete();
      });

      final adapter = VoxCpm2NativeAdapter(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: '',
        modelName: 'clone',
      );
      final result = await adapter.synthesize(
        TtsRequest(text: 'hello', voice: 'default', refAudioPath: temp.path),
      );

      await handled.future.timeout(const Duration(seconds: 2));
      expect(result.audioBytes, [3, 4, 5]);
      expect(paths, ['/api/voxcpm/tts/upload', '/voxcpm/speech/upload']);
      expect(bodies.last, contains('name="model"'));
      expect(bodies.last, contains('default'));
      expect(bodies.last, contains('name="reference_audio"'));
    },
  );
}

class _CapturedRequest {
  final String method;
  final String path;
  final String body;

  const _CapturedRequest(this.method, this.path, this.body);
}
