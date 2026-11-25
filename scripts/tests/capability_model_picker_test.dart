// The shared model picker: automatic entry, every served model, and a
// choice that is no longer served kept visible as unavailable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/capability_model_picker.dart';

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

/// Text inside the picker's field (the menu keeps its own copies).
Finder field(String text) =>
    find.descendant(of: find.byType(TextField), matching: find.text(text));

void main() {
  final router = CapabilityRouter.fromProviders([_openAi()]);

  Future<void> pump(
    WidgetTester tester,
    (String, String)? value,
    ValueChanged<(String, String)?> onChanged,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CapabilityModelPicker(
            cap: AiCapability.stt,
            router: router,
            value: value,
            automaticLabel: '跟随默认',
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('lists the served models after the automatic entry', (
    tester,
  ) async {
    final picked = <(String, String)?>[];
    await pump(tester, null, picked.add);
    expect(field('跟随默认'), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final stt = router.modelsOf(router.connections.first, AiCapability.stt);
    expect(stt, isNotEmpty);
    await tester.tap(find.text('OpenAI · ${stt.last.label}').last);
    await tester.pumpAndSettle();
    expect(picked, [('openai', stt.last.id)]);
  });

  testWidgets('a choice no longer served shows as unavailable', (tester) async {
    await pump(tester, ('gone', 'old-asr'), (_) {});
    expect(field('old-asr（当前不可用）'), findsOneWidget);
  });

  testWidgets('typing filters the list', (tester) async {
    await pump(tester, null, (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final stt = router.modelsOf(router.connections.first, AiCapability.stt);
    await tester.enterText(find.byType(TextField), stt.last.label);
    await tester.pumpAndSettle();
    // The menu measures every entry offstage; only shown ones are hittable.
    expect(
      find.text('OpenAI · ${stt.first.label}').hitTestable(),
      findsNothing,
    );
    expect(find.text('OpenAI · ${stt.last.label}').hitTestable(), findsWidgets);
  });
}
