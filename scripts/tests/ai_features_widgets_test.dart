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
import 'package:neiroha/presentation/widgets/dialog_tts/dialog_mode_view.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/live_conversation_panel.dart';
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
            (_) => Stream.value(CapabilityRouter.fromProviders(rows)),
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

  testWidgets('live modes stay disabled without the capabilities', (
    tester,
  ) async {
    await pump(
      tester,
      const DialogModeView(
        bankAssets: [],
        voiceId: null,
        script: Text('script-pane'),
      ),
      const [],
    );
    expect(find.text('script-pane'), findsOneWidget);
    final view = tester.widget<SegmentedButton<DialogMode>>(
      find.byType(SegmentedButton<DialogMode>),
    );
    final enabled = {
      for (final s in view.segments) (s.label as Text).data: s.enabled,
    };
    expect(enabled, {'剧本': true, '实时对话': false, '陪聊': false});
  });

  testWidgets('OpenAI enables realtime and companion; switching shows panel', (
    tester,
  ) async {
    await pump(
      tester,
      const DialogModeView(
        bankAssets: [],
        voiceId: null,
        script: Text('script-pane'),
      ),
      [_openAi()],
    );
    final view = tester.widget<SegmentedButton<DialogMode>>(
      find.byType(SegmentedButton<DialogMode>),
    );
    expect(view.segments.every((s) => s.enabled), isTrue);
    await tester.tap(find.text('实时对话'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveConversationPanel), findsOneWidget);
    expect(find.text('script-pane'), findsNothing);
    expect(find.text('选择角色'), findsOneWidget);
  });

  testWidgets('subtitle studio shows routed capabilities', (tester) async {
    await pump(tester, const SubtitleStudioScreen(), [_openAi()]);
    expect(find.text('转写翻译'), findsOneWidget);
    expect(find.textContaining('ASR: OpenAI'), findsOneWidget);
    expect(find.textContaining('LLM: OpenAI'), findsOneWidget);
    expect(find.textContaining('VAD: On-device'), findsOneWidget);
    final run = tester.widget<FilledButton>(
      find.ancestor(of: find.text('开始转写'), matching: find.byType(FilledButton)),
    );
    expect(run.onPressed, isNull); // no media picked yet
  });
}
