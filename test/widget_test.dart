import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';

void main() {
  testWidgets('Sidebar renders one button per NavTab', (tester) async {
    NavTab? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Sidebar(
            selected: NavTab.voiceBank,
            onTabChanged: (tab) => tapped = tab,
          ),
        ),
      ),
    );

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
}
