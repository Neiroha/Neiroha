import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/ai/providers/openai/tts/openai_tts_adapter.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/provider_declaration_service.dart';
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'support/novel_fixture.dart';

void main() {
  late HttpServer server;
  late String base;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}/v1';
  });
  tearDown(() => server.close(force: true));
  Map<String, Object?> response({String status = 'completed'}) => {
    'status': status,
    'output': [
      {
        'type': 'message',
        'role': 'assistant',
        'status': status,
        'content': [
          {'type': 'output_text', 'text': '{"ok":true}'},
        ],
      },
    ],
    'usage': {'input_tokens': 8, 'output_tokens': 4},
  };
  LlmChatAdapter client() => LlmChatAdapter(
    baseUrl: base,
    apiKey: 'fake-test-key',
    modelName: 'gateway-alias',
    route: ServiceRoute.responses,
    endpointPath: 'custom/respond',
    apiKeyHeader: 'api-key',
  );
  Future<LlmStructuredResult> structured(LlmChatAdapter adapter) =>
      adapter.structured(
        messages: [const LlmChatMessage(role: 'user', content: 'return JSON')],
        schemaName: 'result',
        schema: const {'type': 'object'},
        cancellation: TtsCancelToken(),
      );

  test(
    'Responses sends explicit protocol/schema/header and parses completed output',
    () async {
      server.listen((request) async {
        expect(request.uri.path, '/v1/custom/respond');
        expect(request.headers.value('api-key'), 'fake-test-key');
        final payload = jsonDecode(await utf8.decoder.bind(request).join());
        expect(payload['store'], false);
        expect(payload['model'], 'gateway-alias');
        expect(payload['max_output_tokens'], 4096);
        expect(payload['text']['format']['type'], 'json_schema');
        expect(payload.containsKey('messages'), false);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response()));
        await request.response.close();
      });
      final result = await structured(client());
      expect(result.object, {'ok': true});
      expect(result.usage['input_tokens'], 8);
    },
  );

  test(
    'Responses only downgrades explicit format rejection; auth is not retried',
    () async {
      var calls = 0;
      server.listen((request) async {
        calls++;
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType.json;
        if (calls == 1) {
          request.response.statusCode = 400;
          request.response.write(
            '{"error":"unsupported text.format json_schema"}',
          );
        } else if (calls == 2) {
          expect(body['text']['format']['type'], 'json_object');
          request.response.write(jsonEncode(response()));
        } else {
          request.response.statusCode = 401;
          request.response.write('{"error":"invalid key"}');
        }
        await request.response.close();
      });
      expect((await structured(client())).responseFormat, 'json_object');
      await expectLater(structured(client()), throwsA(isA<LlmChatException>()));
      expect(calls, 3);
    },
  );

  test(
    'incomplete Responses JSON is rejected even when syntactically valid',
    () async {
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response(status: 'incomplete')));
        await request.response.close();
      });
      await expectLater(structured(client()), throwsA(isA<LlmChatException>()));
    },
  );

  test(
    'Speech route streams a gateway alias before EOF using the chosen endpoint',
    () async {
      final release = Completer<void>();
      final first = Completer<void>();
      server.listen((request) async {
        expect(request.uri.path, '/v1/tts/custom');
        expect(request.headers.value('x-api-key'), 'fake');
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['model'], 'gpt-realtime-gateway-alias');
        expect(body['response_format'], 'pcm');
        request.response.bufferOutput = false;
        request.response.headers.contentType = ContentType('audio', 'pcm');
        request.response.headers.set('x-audio-sample-rate', '22050');
        request.response.add([1, 0, 2, 0]);
        await request.response.flush();
        await release.future;
        request.response.add([3, 0]);
        await request.response.close();
      });
      final adapter = OpenAiTtsAdapter(
        baseUrl: base,
        apiKey: 'fake',
        modelName: 'gpt-realtime-gateway-alias',
        explicitRoute: ServiceRoute.speech,
        endpointPath: 'tts/custom',
        apiKeyHeader: 'x-api-key',
      );
      var done = false;
      final task = adapter
          .synthesizeStream(
            const TtsRequest(
              text: 'hello',
              voice: 'fable',
              responseFormat: 'pcm',
            ),
            cancellation: TtsCancelToken(),
          )
          .forEach((event) {
            if (event is TtsAudioStarted) {
              expect(event.format.sampleRate, 22050);
            }
            if (event is TtsAudioChunk && !first.isCompleted) first.complete();
            if (event is TtsSynthesisCompleted) done = true;
          });
      await first.future.timeout(const Duration(seconds: 3));
      expect(done, false);
      release.complete();
      await task;
      expect(done, true);
    },
  );

  test(
    'task profiles persist separate models, resolve latest credentials and reject unsafe paths',
    () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedNovelFixture(database);
      final repository = TaskProfileRepository(database);
      await repository.save(
        'book',
        const TaskProfile(
          task: ModelTask.analysis,
          providerId: 'test-provider',
          model: 'reasoner',
          route: ServiceRoute.responses,
        ),
      );
      await repository.save(
        'book',
        const TaskProfile(
          task: ModelTask.synthesis,
          providerId: 'test-provider',
          model: 'speaker',
          route: ServiceRoute.speech,
          endpointPath: 'custom/voice',
        ),
      );
      final provider = (await database.getAllProviders()).firstWhere(
        (p) => p.id == 'test-provider',
      );
      await database.updateProvider(
        provider.copyWith(apiKey: 'rotated-test-key'),
      );
      final binding = await repository.resolve(
        'book',
        ModelTask.analysis,
        provider,
      );
      expect(binding.profile!.model, 'reasoner');
      expect(binding.provider.apiKey, 'rotated-test-key');
      expect(
        (await repository.load('book')).map((p) => p.model),
        containsAll(['reasoner', 'speaker']),
      );
      final stored = await database.getSettingsWithPrefix(
        'novel.taskProfiles.',
      );
      expect(jsonEncode(stored).contains('rotated-test-key'), false);
      for (final path in [
        'https://elsewhere.test/steal',
        '//elsewhere.test/steal',
        '../steal',
        '%2e%2e/steal',
      ]) {
        await expectLater(
          repository.save(
            'book',
            TaskProfile(
              task: ModelTask.analysis,
              providerId: 'test-provider',
              model: 'm',
              route: ServiceRoute.responses,
              endpointPath: path,
            ),
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'self-hosted declaration is explicit, route scoped and preserves user evidence',
    () async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedNovelFixture(database);
      final capabilities = CapabilityRepository(database);
      final provider = (await database.getAllProviders()).first.copyWith(
        baseUrl: base,
      );
      await capabilities.save(
        provider,
        ModelCapability(
          connectionId: capabilities.scope(provider),
          modelId: 'native-a',
          route: ServiceRoute.speech,
          facts: const {
            'streaming': CapabilityEvidence(
              CapabilitySupport.unsupported,
              CapabilitySource.user,
            ),
          },
        ),
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.uri.path, '/v1/.well-known/neiroha-capabilities');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'version': 1,
            'models': [
              {
                'id': 'native-a',
                'routes': {
                  'speech': {'speech': true, 'streaming': true, 'text': null},
                },
              },
            ],
          }),
        );
        await request.response.close();
      });
      final result = await ProviderDeclarationService(
        database,
        capabilities,
      ).read(provider, ServiceRoute.speech);
      expect(
        result.single.capability.support('speech'),
        CapabilitySupport.supported,
      );
      expect(
        result.single.capability.support('streaming'),
        CapabilitySupport.unsupported,
      );
      expect(
        result.single.capability.support('text'),
        CapabilitySupport.unknown,
      );
      expect(
        (await capabilities.load(
          provider,
          'native-a',
          ServiceRoute.responses,
        )).facts,
        isEmpty,
      );
      expect(requests, 1);
    },
  );
}
