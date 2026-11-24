import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_discovery.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/catalog_normalizer.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/llm_model_picker.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

db.TtsProvider _row(AdapterType type, {String base = '', String id = 'p'}) =>
    db.TtsProvider(
      id: id,
      name: type.displayName,
      adapterType: type.name,
      baseUrl: base,
      apiKey: 'fixture',
      defaultModelName: type.defaultModel,
      enabled: true,
      position: 0,
      maxConcurrency: 1,
    );

LlmTraits _traits(Map<String, dynamic> raw) =>
    LlmTraits.fromJson(llmTraitsFromLiteLlm(raw));

final _catalog = LlmTraitsCatalog.fromSnapshot({
  'models': {
    'openai::gpt-6-luna': {
      'endpoints': ['/v1/chat/completions', '/v1/responses'],
      'llm': llmTraitsFromLiteLlm({
        'supports_reasoning': true,
        'supports_none_reasoning_effort': true,
        'supports_minimal_reasoning_effort': false,
        'supports_xhigh_reasoning_effort': true,
        'supports_max_reasoning_effort': true,
        'supports_function_calling': true,
        'supported_modalities': ['text', 'image'],
        'supports_pdf_input': true,
      }),
    },
    'openai::gpt-6-astra': {
      'llm': {'tools': true},
    },
    'openai::chat-only': {
      'endpoints': ['/v1/chat/completions'],
      'llm': {'tools': true},
    },
    'openai::tts-1': {
      'facts': {'speech': 'supported'},
    },
  },
});

void main() {
  group('LiteLLM normalisation', () {
    test('flags become levels, inputs and tools', () {
      final t = _traits({
        'supports_reasoning': true,
        'supports_none_reasoning_effort': true,
        'supports_xhigh_reasoning_effort': true,
        'reasoning_modes': ['standard', 'pro'],
        'default_reasoning_effort': 'none',
        'supported_modalities': ['text', 'image', 'audio', 'video'],
        'supports_pdf_input': true,
        'supports_function_calling': true,
        'supports_parallel_function_calling': true,
        'supports_response_schema': false,
        'max_input_tokens': 922000,
      });
      expect(t.reasoning!.levels, [
        ReasoningEffort.none,
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
        ReasoningEffort.xhigh,
      ]);
      expect(t.reasoning!.canDisable, isTrue);
      expect(t.reasoning!.defaultLevel, ReasoningEffort.none);
      expect(t.reasoning!.modes, ['standard', 'pro']);
      expect(t.inputs, Modality.values.toSet());
      expect(t.tools, isTrue);
      expect(t.parallelTools, isTrue);
      expect(t.structuredOutput, isFalse);
      expect(t.contextWindow, 922000);
    });

    test('explicit level list wins; bare reasoning keeps levels unknown', () {
      expect(
        _traits({
          'reasoning_effort_levels': ['max', 'low', 'high'],
        }).reasoning!.levels,
        [ReasoningEffort.low, ReasoningEffort.high, ReasoningEffort.max],
      );
      final bare = _traits({'supports_reasoning': true}).reasoning!;
      expect(bare.supported, isTrue);
      expect(bare.levels, isEmpty);
      expect(
        _traits({'supports_reasoning': false}).reasoning!.supported,
        isFalse,
      );
      expect(_traits({}).isUnknown, isTrue);
      expect(_traits({'supports_vision': true}).inputs, {
        Modality.text,
        Modality.image,
      });
    });

    test('traits survive a JSON round trip', () {
      const t = LlmTraits(
        inputs: {Modality.text, Modality.audio},
        tools: false,
        reasoning: ReasoningSpec(
          levels: [ReasoningEffort.low, ReasoningEffort.high],
          defaultLevel: ReasoningEffort.low,
        ),
        maxOutputTokens: 8192,
      );
      final back = LlmTraits.fromJson(t.toJson());
      expect(back.inputs, t.inputs);
      expect(back.tools, isFalse);
      expect(back.reasoning, t.reasoning);
      expect(back.maxOutputTokens, 8192);
    });
  });

  group('discovery', () {
    final openai = connectionForProvider(_row(AdapterType.openaiTts));

    test('keeps chat models, folds dated aliases, respects protocol', () async {
      final inventory = await LlmDiscovery(
        _catalog,
        lister: (_) async => {
          for (final id in [
            'gpt-6-luna',
            'gpt-6-astra',
            'gpt-6-astra-2026-09-03',
            'chat-only',
            'tts-1',
            'text-embedding-3-small',
          ])
            id: {'id': id},
        },
      ).discover(openai);
      expect(inventory.state, HealthState.ok);
      final ids = inventory.models.map((m) => m.id).toList();
      expect(ids.first, 'gpt-6-luna');
      expect(ids, contains('gpt-6-astra'));
      expect(ids, isNot(contains('gpt-6-astra-2026-09-03')));
      expect(ids, isNot(contains('chat-only'))); // Responses-only connection
      expect(ids, isNot(contains('tts-1')));
      expect(ids, isNot(contains('text-embedding-3-small')));
      final luna = inventory.find('gpt-6-luna')!;
      expect(luna.llm!.reasoning!.levels.last, ReasoningEffort.max);
      expect(luna.llm!.accepts(Modality.pdf), isTrue);
      expect(inventory.find('gpt-6-astra')!.source, DescriptorSource.provider);
      // Hand-written lineups are gone: only listed models are shown.
      expect(inventory.find('gpt-6-sol'), isNull);
    });

    test('rejected credentials keep the catalog and report failure', () async {
      final inventory = await LlmDiscovery(
        _catalog,
        lister: (_) async =>
            throw const AiProviderException('bad key', statusCode: 401),
      ).discover(openai);
      expect(inventory.state, HealthState.failed);
      expect(inventory.find('gpt-6-luna')!.llm!.tools, isTrue);
    });

    test('gateway listings supply their own traits', () async {
      final gateway = connectionForProvider(
        _row(AdapterType.openaiCompatible, base: 'https://llm.example/v1'),
      );
      final inventory = await LlmDiscovery(
        _catalog,
        lister: (_) async => {
          'vision-pro': {
            'id': 'vision-pro',
            'architecture': {
              'input_modalities': ['text', 'image', 'file'],
              'output_modalities': ['text'],
            },
            'supported_parameters': ['tools', 'reasoning'],
            'context_length': 200000,
          },
          'local-model': {'id': 'local-model'},
        },
      ).discover(gateway);
      final vision = inventory.find('vision-pro')!.llm!;
      expect(vision.inputs, {Modality.text, Modality.image, Modality.pdf});
      expect(vision.tools, isTrue);
      expect(vision.reasoning!.supported, isTrue);
      expect(inventory.find('local-model'), isNotNull);
    });

    test('only providers with an LLM are offered for role tasks', () {
      expect(providerOffersLlm(_row(AdapterType.openaiTts)), isTrue);
      expect(providerOffersLlm(_row(AdapterType.geminiTts)), isTrue);
      expect(providerOffersLlm(_row(AdapterType.elevenLabs)), isFalse);
      expect(providerOffersLlm(_row(AdapterType.azureTts)), isFalse);
      expect(providerOffersLlm(_row(AdapterType.systemTts)), isFalse);
    });
  });

  testWidgets('picker shows traits and blocks models without tools', (
    tester,
  ) async {
    final row = _row(AdapterType.openaiTts);
    final connection = connectionForProvider(row);
    final inventory = LlmInventory(
      connection,
      [
        connection
            .describe(AiCapability.llm, 'gpt-6-luna')!
            .copyWith(llm: _catalog.lookup('openai', 'gpt-6-luna')),
        ModelDescriptor(
          id: 'no-tools',
          capability: AiCapability.llm,
          protocol: AiProtocol.openAiResponses,
          source: DescriptorSource.provider,
          llm: const LlmTraits(tools: false),
        ),
      ],
      state: HealthState.ok,
      listed: const {'gpt-6-luna', 'no-tools'},
    );
    ModelDescriptor? picked;
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsProvidersStreamProvider.overrideWith((_) => Stream.value([row])),
          llmTraitsCatalogProvider.overrideWith((_) async => _catalog),
          llmInventoryProvider.overrideWith((_, _) async => inventory),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showLlmModelPicker(
                context,
                providerId: row.id,
                requireTools: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('思考 5 档 low→max，可关闭'), findsOneWidget);
    expect(find.textContaining('文本 · 图片 · PDF'), findsOneWidget);
    expect(find.text('no-tools'), findsNothing); // tools-only filter is on
    await tester.tap(find.text('仅显示支持工具调用'));
    await tester.pumpAndSettle();
    expect(find.text('no-tools'), findsOneWidget);
    await tester.tap(find.text('no-tools'));
    await tester.pumpAndSettle();
    expect(picked, isNull); // blocked: role tasks need tools
    await tester.tap(find.text('gpt-6-luna'));
    await tester.pumpAndSettle();
    expect(picked?.id, 'gpt-6-luna');
  });
}
