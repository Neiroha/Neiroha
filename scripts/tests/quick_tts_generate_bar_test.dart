// The quick test composer: one line that grows, Enter to generate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/quick_tts/generate_bar.dart';

void main() {
  testWidgets('starts one line high, grows, and Enter generates', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (context, setState) {
                controller.addListener(() => setState(() {}));
                return QuickTtsGenerateBar(
                  controller: controller,
                  generating: false,
                  roomy: true,
                  onGenerate: () => sent++,
                  onStop: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    double height() => tester.getSize(find.byType(TextField)).height;
    final oneLine = height();
    expect(oneLine, lessThan(60));

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'a\nb\nc\nd');
    await tester.pump();
    expect(height(), greaterThan(oneLine * 2));

    // Shift+Enter adds a line instead of generating.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sent, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sent, 1);

    // Enough lines to pass the cap: it stops growing and scrolls.
    await tester.enterText(
      find.byType(TextField),
      List.filled(30, 'x').join('\n'),
    );
    await tester.pump();
    final capped = height();
    await tester.enterText(
      find.byType(TextField),
      List.filled(60, 'x').join('\n'),
    );
    await tester.pump();
    expect(height(), capped);
  });
}
