import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';
import 'package:neiroha/providers/app_providers.dart';

void main() {
  late AppDatabase database;
  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester, ValueChanged<NavTab> onTab) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                Sidebar(selected: NavTab.voiceBank, onTabChanged: onTab),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Sidebar renders one button per NavTab', (tester) async {
    NavTab? tapped;
    await pump(tester, (tab) => tapped = tab);

    for (final tab in NavTab.values) {
      expect(
        find.byTooltip(tab.label),
        findsOneWidget,
        reason: 'missing sidebar tooltip for ${tab.name}',
      );
    }

    await tester.tap(find.byTooltip(NavTab.dialogTts.label));
    expect(tapped, NavTab.dialogTts);
  });

  testWidgets('the toggle opens the sidebar with labels and keeps its width', (
    tester,
  ) async {
    await pump(tester, (_) {});
    expect(tester.getSize(find.byType(Sidebar)).width, 72);
    expect(find.text(NavTab.dialogTts.label), findsNothing);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Sidebar)).width, greaterThan(150));
    expect(find.text(NavTab.dialogTts.label), findsOneWidget);
    final saved = await tester.runAsync(
      () => database.getSetting(Sidebar.widthSetting),
    );
    expect(double.parse(saved!), greaterThan(150));

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Sidebar)).width, 72);
  });
}
