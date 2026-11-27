import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/screens/subtitle_studio_screen.dart';
import 'package:neiroha/presentation/screens/character_chat_screen.dart';
import 'package:neiroha/presentation/widgets/character_chat/new_chat_dialog.dart';
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

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    List<db.TtsProvider> rows,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          aiCapabilityRouterProvider.overrideWith(
            (_) async => CapabilityRouter.fromProviders(rows),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new chat offers only the engines the services run', (
    tester,
  ) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showNewChatDialog(
            context: context,
            characters: const [],
            available: const {},
          ),
          child: const Text('open'),
        ),
      ),
      const [],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('请先在语音库中添加角色。'), findsOneWidget);
    final create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '创建'),
    );
    expect(create.onPressed, isNull);
  });

  testWidgets('character chat creates a live call with OpenAI', (tester) async {
    final openAi = _openAi();
    await database.insertProvider(
      db.TtsProvidersCompanion.insert(
        id: openAi.id,
        name: openAi.name,
        adapterType: openAi.adapterType,
        baseUrl: openAi.baseUrl,
      ),
    );
    await database.insertVoiceAsset(
      db.VoiceAssetsCompanion.insert(
        id: 'nagato',
        name: '长门',
        providerId: openAi.id,
        taskMode: 'presetVoice',
      ),
    );
    await pump(tester, const CharacterChatScreen(), [openAi]);
    expect(find.text('还没有聊天，选一个角色开始吧。'), findsOneWidget);
    await tester.tap(find.byTooltip('新聊天'));
    await tester.pumpAndSettle();
    final engines = tester.widget<SegmentedButton<ChatEngine>>(
      find.byType(SegmentedButton<ChatEngine>),
    );
    expect(engines.segments.every((s) => s.enabled), isTrue);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('长门').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('实时通话'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    final sessions = (await tester.runAsync(
      () => database.watchChatSessions().first,
    ))!;
    expect(sessions.single.engine, 'realtime');
    expect(sessions.single.title, '长门');
    expect(find.text('开始通话'), findsOneWidget);
    expect(find.textContaining('开始通话后直接说话'), findsOneWidget);
    // Drift closes its stream queries on a timer once nothing listens.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // Drift closes its stream queries on a timer once nothing listens.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('subtitle studio shows routed capabilities', (tester) async {
    await pump(tester, const SubtitleStudioScreen(), [_openAi()]);
    expect(find.text('转写翻译'), findsOneWidget);
    // Each step offers its models, following the defaults until one is
    // picked for this page.
    expect(find.text('使用的模型'), findsOneWidget);
    // Each picker's field shows its current choice.
    Finder field(String text) => find.descendant(
      of: find.byType(TextField),
      matching: find.textContaining(text),
    );
    expect(field('跟随默认（OpenAI ·'), findsNWidgets(2));
    expect(field('跟随默认（On-device ·'), findsOneWidget);
    final run = tester.widget<FilledButton>(
      find.ancestor(of: find.text('开始转写'), matching: find.byType(FilledButton)),
    );
    expect(run.onPressed, isNull); // no media picked yet
  });
}
