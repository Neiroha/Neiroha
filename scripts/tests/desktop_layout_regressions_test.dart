import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/screens/voice_asset_screen.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/phase_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/phase_tts/script_workspace.dart';
import 'package:neiroha/presentation/widgets/providers/add_provider_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';

Widget _app(Widget body) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light(),
  home: Scaffold(body: body),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  final bank = db.VoiceBank(
    id: 'qa-bank',
    name: 'Sample Bank',
    isActive: true,
    createdAt: DateTime(2026, 11, 25),
    loudnessTargetLufs: -16,
  );

  for (final (name, open, fields) in [
    (
      'dialog',
      showCreateDialogTtsProjectDialog,
      (Object? result) =>
          ((result as CreateDialogProjectResult).name, result.bankId),
    ),
    (
      'phase',
      showCreatePhaseTtsProjectDialog,
      (Object? result) =>
          ((result as CreatePhaseProjectResult).name, result.bankId),
    ),
  ]) {
    testWidgets('$name creation can cancel and reopen without errors', (
      tester,
    ) async {
      Object? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await open(context: context, banks: [bank]),
              child: const Text('Open project dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open project dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.uiCancel));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, isNull);

      await tester.tap(find.text('Open project dialog'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Test Project  ');
      await tester.tap(find.text(l10n.uiCreate));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fields(result), ('Test Project', bank.id));
    });
  }

  for (final size in [const Size(360, 720), const Size(720, 420)]) {
    testWidgets('provider picker stays usable in a $size window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AddProviderDialog(onAdd: (_) async {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell).hitTestable(),
      );
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.uiCreate),
            )
            .onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('narrow audio header keeps both actions inside the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioTracksStreamProvider.overrideWith((_) => Stream.value([])),
        ],
        child: _app(const VoiceAssetScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final header = find.byType(PageHeader);
    for (final label in [l10n.uiRecord, l10n.uiUploadAudio]) {
      final action = find.descendant(
        of: header,
        matching: find.byTooltip(label),
      );
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getRect(action).right, lessThanOrEqualTo(360));
    }
  });

  testWidgets('Phase TTS fits a long rule name beside its actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = ScriptHighlightController(text: 'A test line.');
    addTearDown(controller.dispose);
    const rule = SplitRule(
      id: 'long-rule',
      name: 'A custom splitting rule with a very long name',
      mode: 'newline',
    );
    SplitRule? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          splitRulesProvider.overrideWith((_) async => [rule]),
        ],
        child: _app(
          PhaseScriptWorkspace(
            controller: controller,
            onScriptChanged: () {},
            onAutoSplit: (value) => selected = value,
            roleAction: OutlinedButton(
              onPressed: () {},
              child: Text(l10n.phaseAutoRoles),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l10n.uiAutoSplit));
    expect(selected, rule);
  });
}
