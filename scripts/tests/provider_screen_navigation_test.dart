// The AI services page: navigation beside the page, the providers page,
// and a provider's settings beside the provider list.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/catalog/llm_traits_catalog.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/screens/provider_screen.dart';
import 'package:neiroha/presentation/widgets/providers/provider_editor.dart';
import 'package:neiroha/presentation/widgets/providers/provider_hub.dart';
import 'package:neiroha/presentation/widgets/providers/provider_models.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

db.TtsProvider _row(String id, String name, int position) => db.TtsProvider(
  id: id,
  name: name,
  adapterType: AdapterType.openaiTts.name,
  baseUrl: 'http://127.0.0.1:9/v1',
  apiKey: 'fixture',
  defaultModelName: AdapterType.openaiTts.defaultModel,
  enabled: true,
  position: position,
  maxConcurrency: 1,
);

void main() {
  final rows = [_row('a', 'Alpha AI', 0), _row('b', 'Beta AI', 1)];

  Future<void> pump(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsProvidersStreamProvider.overrideWith((_) => Stream.value(rows)),
          aiCapabilityRouterProvider.overrideWith(
            (_) async => CapabilityRouter.fromProviders(rows),
          ),
          connectionCapabilitiesProvider.overrideWith(
            (_) => Stream.value(const []),
          ),
          providerModelsProvider.overrideWith((_) => Stream.value(const [])),
          capabilityDefaultsProvider.overrideWith(
            (_) => Stream.value(const []),
          ),
          llmTraitsCatalogProvider.overrideWith(
            (_) => Completer<LlmTraitsCatalog>().future,
          ),
          providerBindingsProvider.overrideWith((_, _) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProviderScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('wide: providers page, then a provider beside the list', (
    tester,
  ) async {
    await pump(tester, const Size(1400, 900));
    // Root: navigation beside the default-model page.
    expect(find.text('默认模型'), findsWidgets);
    expect(find.text('2 个连接 · 2 个已启用'), findsOneWidget);
    expect(find.byType(ProvidersPage), findsNothing);

    await tapText(tester, '服务商');
    expect(find.byType(ProvidersPage), findsOneWidget);
    expect(find.text('Alpha AI'), findsOneWidget);
    expect(find.text('Beta AI'), findsOneWidget);

    await tapText(tester, 'Beta AI');
    // Provider level: the list on the left, Beta's settings on the right.
    expect(find.byType(ProviderEditor), findsOneWidget);
    expect(find.text('Alpha AI'), findsOneWidget);
    expect(find.text('默认模型'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(find.byType(ProviderEditor), findsNothing);
    expect(find.byType(ProvidersPage), findsOneWidget);
    expect(find.text('默认模型'), findsWidgets);
  });

  testWidgets('narrow: one pane at a time with back buttons', (tester) async {
    await pump(tester, const Size(500, 900));
    expect(find.text('服务商'), findsOneWidget);
    expect(find.text('Alpha AI'), findsNothing);

    await tapText(tester, '服务商');
    expect(find.text('Alpha AI'), findsOneWidget);

    await tapText(tester, 'Alpha AI');
    expect(find.byType(ProviderEditor), findsOneWidget);
    expect(find.text('Beta AI'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(find.text('Beta AI'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(find.text('2 个连接 · 2 个已启用'), findsOneWidget);
  });
}
