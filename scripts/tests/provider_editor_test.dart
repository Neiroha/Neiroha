// The provider editor's capability tabs.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/providers/provider_editor.dart';
import 'package:neiroha/presentation/widgets/providers/provider_models.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

db.TtsProvider _openAi() => db.TtsProvider(
  id: 'openai',
  name: 'OpenAI',
  adapterType: AdapterType.openaiTts.name,
  baseUrl: 'http://127.0.0.1:9/v1',
  apiKey: 'fixture',
  defaultModelName: AdapterType.openaiTts.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

void main() {
  late db.AppDatabase database;
  setUp(() => database = db.AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          connectionCapabilitiesProvider.overrideWith(
            (_) => Stream.value(const []),
          ),
          providerModelsProvider.overrideWith((_) => Stream.value(const [])),
          capabilityDefaultsProvider.overrideWith(
            (_) => Stream.value(const []),
          ),
          // Without the public catalog the tab lists the plugin's models.
          llmTraitsCatalogProvider.overrideWith(
            (_) => Completer<LlmTraitsCatalog>().future,
          ),
          providerBindingsProvider.overrideWith((_, _) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProviderEditor(provider: _openAi())),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text(label)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('one tab per capability, with the language models', (
    tester,
  ) async {
    await pump(tester);
    final tabs = find.byType(TabBar);
    for (final label in ['概览', '大模型', '语音合成', '限额']) {
      expect(
        find.descendant(of: tabs, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    await openTab(tester, '大模型');
    final llm = connectionForProvider(_openAi()).models(AiCapability.llm);
    expect(llm, isNotEmpty);
    expect(find.text(llm.first.label), findsOneWidget);
    expect(find.text('从账号发现'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a star sets the capability default; the switch turns it off', (
    tester,
  ) async {
    await pump(tester);
    await openTab(tester, '大模型');
    final llm = connectionForProvider(_openAi()).models(AiCapability.llm);
    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    final defaults = await tester.runAsync(database.getCapabilityDefaults);
    expect(defaults!.single.capability, 'llm');
    expect(defaults.single.connectionId, 'openai');
    expect(defaults.single.modelId, llm.first.id);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    final lanes = await tester.runAsync(database.getConnectionCapabilities);
    expect(lanes!.single.capability, 'llm');
    expect(lanes.single.enabled, isFalse);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
