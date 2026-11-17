import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';
import 'package:neiroha/data/services/capabilities/model_discovery_service.dart';
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
                {'id': 'brand-new-model'},
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
