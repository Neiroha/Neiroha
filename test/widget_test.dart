import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:q_vox_lab/main.dart';

void main() {
  testWidgets('App launches with sidebar', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QVoxLabApp()));
    expect(find.text('Quick TTS'), findsOneWidget);
  });
}
