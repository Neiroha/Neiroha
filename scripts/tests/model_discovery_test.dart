// Model discovery from public data: the models.dev catalog (normalized,
// layered over LiteLLM, refreshed daily), OpenRouter listing fields, and
// self-hosted `.well-known/neiroha-capabilities` v2 declarations.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/catalog/model_catalog_refresher.dart';
import 'package:neiroha/data/ai/protocols/openai/openai_model_list.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/capability_declaration.dart';
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';
import 'package:neiroha/data/services/capabilities/provider_declaration_service.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';

import 'support/novel_fixture.dart';

db.TtsProvider _row(AdapterType type, {String base = ''}) => db.TtsProvider(
  id: 'p',
  name: type.displayName,
  adapterType: type.name,
  baseUrl: base,
  apiKey: 'fixture',
  defaultModelName: type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

/// A trimmed models.dev `api.json`.
Map<String, dynamic> _modelsDev() => {
  'openai': {
    'models': {
      'gpt-6-luna': {
        'name': 'GPT-6 Luna',
        'release_date': '2026-08-01',
        'tool_call': true,
        'structured_output': true,
        'reasoning': true,
        'reasoning_options': [
          {
            'type': 'effort',
            'values': ['low', 'medium', 'high', 'xhigh'],
          },
          {'type': 'toggle'},
        ],
        'modalities': {
          'input': ['text', 'image', 'pdf'],
          'output': ['text'],
        },
        'limit': {'context': 1050000, 'output': 128000},
      },
      'gpt-6-sol': {
        'name': 'GPT-6 Sol',
        'release_date': '2026-09-01',
        'tool_call': true,
        'reasoning': false,
        'modalities': {
          'input': ['text'],
          'output': ['text'],
        },
      },
      'gpt-4o': {
        'name': 'GPT-4o',
        'release_date': '2024-05-13',
        'status': 'deprecated',
        'tool_call': true,
        'modalities': {
          'input': ['text'],
          'output': ['text'],
        },
      },
      'text-embedding-9': {'name': 'Embed', 'type': 'embedding'},
      'image-gen': {
        'name': 'Image',
        'modalities': {
          'input': ['text'],
          'output': ['image'],
        },
      },
    },
  },
  'google': {
    'models': {
      'gemini-4-neon': {
        'name': 'Gemini 4 Neon',
        'release_date': '2026-10-01',
        'tool_call': true,
        'reasoning': true,
        'reasoning_options': [
          {
            'type': 'effort',
            'values': ['low', 'medium', 'high', 'xhigh'],
          },
        ],
        'modalities': {
          'input': ['text', 'image', 'video'],
          'output': ['text'],
        },
      },
    },
  },
  'openrouter': {
    'models': {
      'anything': {'name': 'Gateway entries are not official facts'},
    },
  },
};

class _Fixed implements HttpClientAdapter {
  _Fixed(this.body, {this.status = 200});
  final List<int> body;
  final int status;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromBytes(body, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('models.dev catalog', () {
    final snapshot = normalizeModelsDevCatalog(_modelsDev(), digest: 'x');
    final models = snapshot['models'] as Map;

    test('keeps official chat models with their stated traits', () {
      expect(
        models.keys,
        unorderedEquals([
          'openai::gpt-6-luna',
          'openai::gpt-6-sol',
          'openai::gpt-4o',
          'gemini::gemini-4-neon',
        ]),
      );
      expect(snapshot['license'], contains('MIT'));
      final luna = LlmTraits.fromJson(
        Map<String, dynamic>.from(models['openai::gpt-6-luna']['llm'] as Map),
      );
      // The thinking toggle adds `none` to the effort levels.
      expect(luna.reasoning!.levels, [
        ReasoningEffort.none,
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
        ReasoningEffort.xhigh,
      ]);
      expect(luna.accepts(Modality.pdf), isTrue);
      expect(luna.contextWindow, 1050000);
      expect(luna.structuredOutput, isTrue);
      expect(models['openai::gpt-4o']['deprecated'], isTrue);
    });

    test('layers over LiteLLM: newer facts win, gaps are filled', () {
      final litellm = LlmTraitsCatalog.fromSnapshot({
        'source': 'https://raw.githubusercontent.com/x',
        'models': {
          'openai::gpt-6-sol': {
            'llm': {'context': 400000, 'parallelTools': true},
          },
          'openai::gpt-legacy': {
            'llm': {'tools': false},
          },
        },
      });
      final catalog = LlmTraitsCatalog.fromSnapshot(snapshot).over(litellm);
      final sol = catalog.lookup('openai', 'gpt-6-sol')!;
      expect(sol.reasoning!.supported, isFalse); // models.dev
      expect(sol.contextWindow, 400000); // filled from LiteLLM
      expect(catalog.lookup('openai', 'gpt-legacy')!.tools, isFalse);
      expect(catalog.isDeprecated('openai', 'gpt-4o'), isTrue);
      expect(catalog.sources.first, startsWith('models.dev'));
      // Newest first, deprecated hidden.
      expect(catalog.vendorModels('openai').map((m) => m.id), [
        'gpt-6-sol',
        'gpt-6-luna',
      ]);
    });

    test('bundled snapshot covers the plugins\' recommended models', () {
      final raw = File(LlmTraitsCatalog.modelsDevAsset).readAsStringSync();
      final bundled = LlmTraitsCatalog.fromSnapshot(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      for (final type in [AdapterType.openaiTts, AdapterType.geminiTts]) {
        final c = connectionForProvider(_row(type));
        final model = c.defaultModel(AiCapability.llm)!;
        expect(
          bundled.lookup(catalogVendor(c), model.id),
          isNotNull,
          reason: model.id,
        );
      }
    });
  });

  group('discovery from the catalog', () {
    final catalog = LlmTraitsCatalog.fromSnapshot(
      normalizeModelsDevCatalog(_modelsDev(), digest: 'x'),
    );

    test('offline: recommended model first, then the vendor lineup', () {
      final inventory = LlmDiscovery(
        catalog,
      ).offline(connectionForProvider(_row(AdapterType.openaiTts)));
      final ids = inventory.models.map((m) => m.id).toList();
      expect(ids.first, 'gpt-6-luna');
      expect(ids, contains('gpt-6-sol'));
      expect(ids, isNot(contains('gpt-4o'))); // deprecated
      expect(inventory.find('gpt-6-sol')!.displayName, 'GPT-6 Sol');
    });

    test(
      'online: catalog-only models the account does not list are hidden',
      () async {
        final inventory = await LlmDiscovery(
          catalog,
          lister: (_) async => {
            'gpt-6-luna': {'id': 'gpt-6-luna'},
          },
        ).discover(connectionForProvider(_row(AdapterType.openaiTts)));
        expect(inventory.models.map((m) => m.id), ['gpt-6-luna']);
      },
    );

    test('vendor-doc defaults complete catalog thinking levels', () {
      final inventory = LlmDiscovery(
        catalog,
      ).offline(connectionForProvider(_row(AdapterType.geminiTts)));
      final neon = inventory.find('gemini-4-neon')!.llm!.reasoning!;
      expect(neon.levels.last, ReasoningEffort.xhigh);
      expect(neon.defaultLevel, ReasoningEffort.high);
    });
  });

  group('OpenRouter listing', () {
    final raw = <String, dynamic>{
      'id': 'vendor/thinker',
      'architecture': {
        'input_modalities': ['text'],
        'output_modalities': ['text'],
      },
      'supported_parameters': ['tools', 'reasoning'],
      'reasoning': {
        'supported_efforts': ['low', 'high', 'turbo'],
        'default_effort': 'high',
        'mandatory': false,
      },
      'expiration_date': '2027-03-01T00:00:00Z',
      'endpoints': ['/api/v1/chat/completions'],
    };

    test('reads effort levels, default, expiry and endpoints', () {
      final spec = llmTraitsFromListing(raw).reasoning!;
      expect(spec.levels, [
        ReasoningEffort.none,
        ReasoningEffort.low,
        ReasoningEffort.high,
      ]);
      expect(spec.defaultLevel, ReasoningEffort.high);
      expect(listedShutdown(raw), '2027-03-01');
      expect(listedEndpoints(raw), ['/api/v1/chat/completions']);
    });

    test('a gateway model carries its shutdown date', () async {
      final gateway = connectionForProvider(
        _row(AdapterType.openaiCompatible, base: 'https://llm.example/v1'),
      );
      final inventory = await LlmDiscovery(
        LlmTraitsCatalog.empty,
        lister: (_) async => {'vendor/thinker': raw},
      ).discover(gateway);
      expect(inventory.find('vendor/thinker')!.shutdownAt, '2027-03-01');
    });
  });

  group('daily refresh', () {
    late db.AppDatabase database;
    setUp(() => database = db.AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    test('downloads once a day and serves the cached copy', () async {
      final http = _Fixed(utf8.encode(jsonEncode(_modelsDev())));
      var now = DateTime.utc(2026, 11, 23, 8);
      final refresher = ModelCatalogRefresher(
        database,
        http: Dio()..httpClientAdapter = http,
        now: () => now,
      );
      expect(await refresher.cached(), isNull);
      expect(await refresher.refresh(), isTrue);
      expect(await refresher.refresh(), isFalse); // same day
      expect(http.calls, 1);
      final cached = (await refresher.cached())!;
      expect(cached.lookup('gemini', 'gemini-4-neon'), isNotNull);
      now = now.add(const Duration(days: 1, minutes: 1));
      expect(await refresher.refresh(), isTrue);
      expect(http.calls, 2);
    });

    test('a failed download keeps the cache', () async {
      final good = ModelCatalogRefresher(
        database,
        http: Dio()
          ..httpClientAdapter = _Fixed(utf8.encode(jsonEncode(_modelsDev()))),
      );
      await good.refresh();
      final broken = ModelCatalogRefresher(
        database,
        http: Dio()..httpClientAdapter = _Fixed(utf8.encode('{}'), status: 502),
      );
      expect(await broken.refresh(force: true), isFalse);
      expect(
        (await broken.cached())!.lookup('openai', 'gpt-6-luna'),
        isNotNull,
      );
    });
  });

  group('capability declaration v2', () {
    final v2 = {
      'version': 2,
      'name': 'Local Irodori',
      'auth': {'header': 'X-Api-Key'},
      'models': [
        {
          'id': 'azurlane',
          'name': 'Azur Lane voices',
          'languages': ['ja', 'zh'],
          'voices': [
            {
              'id': 'al-ship-30505-ja',
              'name': 'Nagato',
              'languages': ['ja'],
            },
            'al-ship-10001-ja',
          ],
          'streaming': {
            'formats': ['pcm'],
          },
          'paths': {'speech': 'audio/speech', 'voices': 'voices'},
          'routes': {
            'speech': {'speech': true, 'instructions': null},
          },
        },
        {
          'id': 'chat-helper',
          'routes': {
            'chatCompletions': {'text': true},
          },
        },
      ],
    };

    test('parses voices, languages, streaming, paths and auth', () {
      final d = CapabilityDeclaration.parse(v2);
      expect(d.version, 2);
      expect(d.auth!.header, 'X-Api-Key');
      final m = d.models.first;
      expect(m.languages, ['ja', 'zh']);
      expect(m.voices.map((v) => v.label), [
        'Nagato [al-ship-30505-ja]',
        'al-ship-10001-ja',
      ]);
      expect(m.paths['speech'], 'audio/speech');
      final facts = CapabilityDeclaration.evidence(
        m,
        ServiceRoute.speech,
        DateTime.utc(2026),
      )!;
      // Stream formats imply streaming.
      expect(facts['streaming']!.support, CapabilitySupport.supported);
      expect(facts['instructions']!.support, CapabilitySupport.unknown);
    });

    test('v1 documents still parse; v2-only fields are ignored there', () {
      final d = CapabilityDeclaration.parse({
        'version': 1,
        'models': [
          {
            'id': 'a',
            'voices': ['ignored'],
            'routes': {
              'speech': {'speech': true},
            },
          },
        ],
      });
      expect(d.models.single.voices, isEmpty);
    });

    test('rejects escaping paths, bad headers and duplicate voices', () {
      Map<String, dynamic> withModel(Map<String, dynamic> extra) => {
        'version': 2,
        'models': [
          {'id': 'a', 'routes': <String, dynamic>{}, ...extra},
        ],
      };
      for (final bad in [
        withModel({
          'paths': {'speech': 'https://evil.example/steal'},
        }),
        withModel({
          'paths': {'speech': '../admin'},
        }),
        withModel({
          'voices': ['x', 'x'],
        }),
        withModel({
          'routes': {
            'speech': {'speech': 'yes'},
          },
        }),
        {
          'version': 2,
          'auth': {'header': 'Cookie'},
          'models': [],
        },
        {'version': 3, 'models': []},
      ]) {
        expect(
          () => CapabilityDeclaration.parse(bad),
          throwsFormatException,
          reason: jsonEncode(bad),
        );
      }
    });

    test('reading a declaration stores its voices for the provider', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(v2));
        await request.response.close();
      });
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await seedNovelFixture(database);
      final provider = (await database.getAllProviders()).first.copyWith(
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
      );
      final capabilities = CapabilityRepository(database);
      final result = await ProviderDeclarationService(
        database,
        capabilities,
      ).read(provider, ServiceRoute.speech);
      expect(result.map((m) => m.id), ['azurlane']);
      expect(result.single.voices, hasLength(2));
      expect(result.single.languages, ['ja', 'zh']);
      final voices = [
        for (final b in await database.getBindingsForProvider(provider.id))
          if (b.supportedTaskModes == 'voice') b.modelKey,
      ];
      expect(voices, contains('Nagato [al-ship-30505-ja]'));
      // Reading again adds nothing twice.
      await ProviderDeclarationService(
        database,
        capabilities,
      ).read(provider, ServiceRoute.speech);
      expect(
        [
          for (final b in await database.getBindingsForProvider(provider.id))
            if (b.supportedTaskModes == 'voice') b.modelKey,
        ].where((v) => v == 'Nagato [al-ship-30505-ja]'),
        hasLength(1),
      );
    });
  });
}
