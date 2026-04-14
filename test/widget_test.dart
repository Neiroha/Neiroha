import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/main.dart';

void main() {
  testWidgets('App launches with sidebar', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NeirohaApp()));
    expect(find.text('Quick TTS'), findsOneWidget);
  });
}
