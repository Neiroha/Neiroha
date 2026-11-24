// 「设置 → AI 能力」 page and the provider list's capability tabs.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/providers/capability_defaults_view.dart';
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

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1000, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiCapabilityRouterProvider.overrideWith(
            (_) async => CapabilityRouter.fromProviders([_openAi()]),
          ),
          connectionCapabilitiesProvider.overrideWith(
            (_) => Stream.value(const []),
          ),
          providerModelsProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a capability switch writes a connection × capability row', (
    tester,
  ) async {
    await pump(tester, const CapabilityDefaultsList());
    expect(find.text('语音识别'), findsOneWidget);
    expect(find.text('语音合成'), findsOneWidget);

    final sttCard = find.ancestor(
      of: find.text('语音识别'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: sttCard, matching: find.byType(Switch)).first,
    );
    await tester.pump();
    final rows = await tester.runAsync(database.getConnectionCapabilities);
    expect(rows!.single.capability, 'stt');
    expect(rows.single.enabled, isFalse);
    // Switching it off leaves the lane's limits inherited.
    expect(rows.single.maxConcurrency, isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('provider tabs list the capabilities rows offer', (tester) async {
    await pump(tester, CapabilityFilterBar(providers: [_openAi()]));
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('语音合成'), findsOneWidget);
    expect(find.text('大模型'), findsOneWidget);
    expect(find.text('音乐'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
