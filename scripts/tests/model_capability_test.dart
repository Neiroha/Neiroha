import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';
import 'package:neiroha/data/services/capabilities/model_discovery_service.dart';
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/data/services/capabilities/role_ai_model.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';

void main() {
  late db.AppDatabase database;
  late CapabilityRepository repository;
  db.TtsProvider provider(String url, {String key = ''}) => db.TtsProvider(
    id: 'connection',
    name: 'Connection',
    adapterType: 'openaiCompatible',
    baseUrl: url,
    apiKey: key,
    defaultModelName: 'custom',
    enabled: true,
    position: 0,
    maxConcurrency: 1,
  );
  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repository = CapabilityRepository(database);
  });
  tearDown(() => database.close());

  test('official speech inventory and text suggestions are separate', () async {
    final p = provider(
      'https://api.openai.com/v1',
    ).copyWith(adapterType: 'openaiTts');
    final service = ModelDiscoveryService(database, repository);
    final speech = (await service.modelsForProvider(p)).map((m) => m.id);
    expect(speech, contains('gpt-realtime-2.1-mini'));
    expect(speech, isNot(contains(defaultRoleAiModel)));
    final suggested = await service.suggestedRoleModel(
      p,
      ServiceRoute.chatCompletions,
    );
    expect(suggested!.id, defaultRoleAiModel);
    expect(
      suggested.capability.support(roleAiToolCapability),
      CapabilitySupport.supported,
    );
    expect(suggested.capability.availability, ModelAvailability.unverified);
    await expectLater(
      RoleAiModel(
        repository,
      ).requireTools(p, 'gpt-realtime-2.1-mini', ServiceRoute.chatCompletions),
      throwsStateError,
    );
  });

  test(
    'initial role connections use the correct text routes and only allowed adapters',
    () {
      final google = provider(
        'https://generativelanguage.googleapis.com',
      ).copyWith(adapterType: 'geminiTts');
      final minimax = provider(
        'https://api.minimax.io',
      ).copyWith(adapterType: 'minimaxTts');
      expect(
        google.roleAiBaseUrl,
        'https://generativelanguage.googleapis.com/v1beta/openai/',
      );
      expect(minimax.roleAiBaseUrl, 'https://api.minimax.io/v1/');
      expect(
        google
            .copyWith(baseUrl: 'https://custom.example/gateway')
            .roleAiBaseUrl,
        'https://custom.example/gateway',
      );
      expect(google.supportsRoleAi && minimax.supportsRoleAi, isTrue);
      for (final type in [
        'cosyvoice',
        'voxcpm2Native',
        'azureTts',
        'gptSovits',
        'elevenLabs',
        'indexTts',
      ]) {
        expect(
          google.copyWith(adapterType: type).supportsRoleAi,
          isFalse,
          reason: type,
        );
      }
    },
  );

  test(
    'tool compatibility is verified once per route without sending script text',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var probes = 0;
      server.listen((request) async {
        expect(request.uri.path, '/v1/chat/completions');
        expect(request.headers.value('api-key'), 'test-fixture');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['model'], 'capable');
        expect((body['tool_choice'] as Map)['function'], {
          'name': 'neiroha_check',
        });
        expect(
          (body['messages'] as List).single['content'],
          contains('neiroha_check'),
        );
        probes++;
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'tool_calls': [
                      {
                        'type': 'function',
                        'function': {
                          'name': 'neiroha_check',
                          'arguments': '{}',
                        },
                      },
                    ],
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });
      final p = provider(
        'http://127.0.0.1:${server.port}/v1',
        key: 'test-fixture',
      ).copyWith(adapterType: 'chatCompletionsTts');
      final roles = RoleAiModel(repository);
      await roles.requireTools(p, 'capable', ServiceRoute.chatCompletions);
      await roles.requireTools(p, 'capable', ServiceRoute.chatCompletions);
      expect(probes, 1);
      expect(
        await roles.support(p, 'capable', ServiceRoute.chatCompletions),
        CapabilitySupport.supported,
      );
      expect(
        await roles.support(p, 'capable', ServiceRoute.responses),
        CapabilitySupport.unknown,
      );
    },
  );

  test(
    'inconclusive tool probes do not cache support or deny a retry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var attempt = 0;
      server.listen((request) async {
        await request.drain<void>();
        final current = attempt++;
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': current == 1 ? 'length' : 'stop',
                  'message': {
                    if (current == 0)
                      'content': 'I could not call the function.',
                    if (current > 0)
                      'tool_calls': [
                        {
                          'type': 'function',
                          'function': {
                            'name': 'neiroha_check',
                            'arguments': current == 2 ? '{' : '{}',
                          },
                        },
                      ],
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });
      final p = provider('http://127.0.0.1:${server.port}/v1');
      final roles = RoleAiModel(repository);
      const route = ServiceRoute.chatCompletions;
      for (var i = 0; i < 3; i++) {
        await expectLater(
          roles.requireTools(p, 'custom', route),
          throwsStateError,
        );
        expect(
          await roles.support(p, 'custom', route),
          CapabilitySupport.unknown,
        );
      }
      await roles.requireTools(p, 'custom', route);
      expect(attempt, 4);
      expect(
        await roles.support(p, 'custom', route),
        CapabilitySupport.supported,
      );
    },
  );

  test(
    'unknown is distinct from unsupported; user overrides survive discovery and successful calls',
    () async {
      final p = provider('https://custom.example/v1');
      expect(
        (await repository.load(
          p,
          'model',
          ServiceRoute.speech,
        )).support('speech'),
        CapabilitySupport.unknown,
      );
      await repository.save(
        p,
        ModelCapability(
          connectionId: repository.scope(p),
          modelId: 'model',
          route: ServiceRoute.speech,
          facts: const {
            'speech': CapabilityEvidence(
              CapabilitySupport.unsupported,
              CapabilitySource.user,
            ),
          },
        ),
      );
      await repository.markSuccess(p, 'model', ServiceRoute.speech, ['speech']);
      final saved = await repository.load(p, 'model', ServiceRoute.speech);
      expect(saved.support('speech'), CapabilitySupport.unsupported);
      expect(saved.availability, ModelAvailability.available);
    },
  );

  test(
    'quota/auth/network errors do not permanently deny model capabilities',
    () async {
      final p = provider('https://custom.example/v1');
      await repository.markSuccess(p, 'model', ServiceRoute.speech, ['speech']);
      await repository.markFailure(p, 'model', ServiceRoute.speech, 429);
      var saved = await repository.load(p, 'model', ServiceRoute.speech);
      expect(saved.support('speech'), CapabilitySupport.supported);
      expect(saved.availability, ModelAvailability.rateLimited);
      await repository.markFailure(p, 'model', ServiceRoute.speech, 401);
      saved = await repository.load(p, 'model', ServiceRoute.speech);
      expect(saved.support('speech'), CapabilitySupport.supported);
      expect(saved.availability, ModelAvailability.authenticationFailed);
    },
  );

  test(
    'connection, account and route scope prevent capability leakage',
    () async {
      final p = provider('https://custom.example/v1', key: 'first');
      await repository.markSuccess(p, 'alias', ServiceRoute.speech, ['speech']);
      for (final other in [
        provider('https://other.example/v1', key: 'first'),
        provider(p.baseUrl, key: 'second'),
      ]) {
        expect(
          (await repository.load(
            other,
            'alias',
            ServiceRoute.speech,
          )).support('speech'),
          CapabilitySupport.unknown,
        );
      }
      expect(
        (await repository.load(
          p,
          'alias',
          ServiceRoute.realtime,
        )).support('speech'),
        CapabilitySupport.unknown,
      );
    },
  );

  test('normalizer ignores sample_spec and leaves absent facts unknown', () {
    final snapshot = normalizeLiteLlmCatalog({
      'sample_spec': {},
      'vendor/new-model': {
        'litellm_provider': 'vendor',
        'mode': 'audio_speech',
        'supported_endpoints': ['/v1/audio/speech'],
      },
    }, digest: 'digest');
    final models = snapshot['models'] as Map;
    expect(models.length, 1);
    final facts = (models['vendor::new-model'] as Map)['facts'] as Map;
    expect(facts['speech'], 'supported');
    expect(facts.containsKey('structuredOutput'), isFalse);
    expect(
      () => normalizeLiteLlmCatalog({}, digest: ''),
      throwsFormatException,
    );
  });

  test(
    'discovery only GETs models; unknown gateway aliases remain unknown and are cached offline',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(request.method, 'GET');
        expect(request.uri.path, '/v1/models');
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'id': 'gpt-known-name'},
                {'id': 'brand-new-model', 'supports_function_calling': true},
              ],
            }),
          );
        await request.response.close();
      });
      final p = provider('http://127.0.0.1:${server.port}/v1');
      final service = ModelDiscoveryService(
        database,
        repository,
        loadCatalog: () async => jsonEncode({
          'version': 1,
          'models': {
            'openai::gpt-known-name': {
              'facts': {'speech': 'supported'},
              'endpoints': [],
            },
          },
        }),
      );
      final models = await service.discover(p, ServiceRoute.speech);
      expect(models, hasLength(2));
      expect(
        models.last.capability.support(roleAiToolCapability),
        CapabilitySupport.supported,
      );
      expect(
        models.first.capability.support('speech'),
        CapabilitySupport.unknown,
      );
      expect((await service.cached(p, ServiceRoute.speech)).map((m) => m.id), [
        'gpt-known-name',
        'brand-new-model',
      ]);
      expect(requests, 1);
    },
  );
}
