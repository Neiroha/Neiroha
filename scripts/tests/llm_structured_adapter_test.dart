import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

void main() {
  Future<LlmChatAdapter> server(
    Future<void> Function(HttpRequest request, Map<String, dynamic> body)
    handler,
  ) async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => http.close(force: true));
    http.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      await handler(request, body);
      await request.response.close();
    });
    return LlmChatAdapter(
      baseUrl: 'http://127.0.0.1:${http.port}/v1',
      apiKey: 'test-key',
      modelName: 'test-model',
    );
  }

  Future<LlmStructuredResult> call(
    LlmChatAdapter adapter, [
    TtsCancelToken? token,
  ]) => adapter.structured(
    messages: const [
      LlmChatMessage(role: 'user', content: 'Return JSON labels.'),
    ],
    schemaName: 'labels',
    schema: const {
      'type': 'object',
      'properties': {},
      'required': [],
      'additionalProperties': false,
    },
    cancellation: token ?? TtsCancelToken(),
  );
  void reply(HttpRequest request, {String reason = 'stop'}) => request.response
    ..headers.contentType = ContentType.json
    ..write(
      jsonEncode({
        'choices': [
          {
            'finish_reason': reason,
            'message': {'content': '{}'},
          },
        ],
        'usage': {'total_tokens': 12},
      }),
    );

  test(
    'strict schema, output bound, usage and finish reason round trip',
    () async {
      final adapter = await server((request, body) async {
        expect(body['response_format']['json_schema']['strict'], isTrue);
        expect(body['max_completion_tokens'], 4096);
        expect(body.containsKey('temperature'), isFalse);
        expect(request.headers.value('authorization'), 'Bearer test-key');
        reply(request);
      });
      final result = await call(adapter);
      expect(result.object, isEmpty);
      expect(result.usage['total_tokens'], 12);
    },
  );

  for (final status in [401, 429, 500]) {
    test(
      'HTTP $status never downgrades or retries even if body mentions response_format',
      () async {
        var calls = 0;
        final adapter = await server((request, _) async {
          calls++;
          request.response
            ..statusCode = status
            ..write('unsupported response_format');
        });
        await expectLater(call(adapter), throwsA(isA<LlmChatException>()));
        expect(calls, 1);
      },
    );
  }

  test(
    'only explicit unsupported formatting falls back, once per format',
    () async {
      final formats = <String>[];
      final adapter = await server((request, body) async {
        formats.add(body['response_format']?['type'] as String? ?? 'none');
        if (formats.length < 3) {
          request.response
            ..statusCode = 400
            ..write('unsupported response_format');
        } else {
          reply(request);
        }
      });
      await call(adapter);
      expect(formats, ['json_schema', 'json_object', 'none']);
    },
  );

  test(
    'truncated output is rejected instead of parsing partial labels',
    () async {
      final adapter = await server(
        (request, _) async => reply(request, reason: 'length'),
      );
      await expectLater(call(adapter), throwsA(isA<LlmChatException>()));
    },
  );

  test('in-flight cancellation aborts the HTTP request', () async {
    final started = Completer<void>();
    final gate = Completer<void>();
    final adapter = await server((_, _) async {
      started.complete();
      await gate.future;
    });
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final token = TtsCancelToken();
    final request = call(adapter, token);
    final assertion = expectLater(
      request,
      throwsA(isA<TtsCancelledException>()),
    );
    await started.future;
    token.cancel();
    await assertion;
    gate.complete();
  });
}
