import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/novel_roles/tool_review_dialog.dart';
import 'support/role_review_fixture.dart';

void main() {
  testWidgets(
    'mobile review requires explicit selection and character dependencies',
    (tester) async {
      final f = RoleReviewFixture();
      final data = await tester.runAsync(() async {
        await f.init();
        final session = await f.service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: f.provider,
          model: 'fake',
          client: ReviewLlm(
            (_, _) async => {
              'actions': [newPerson(), patch(1, 'new:xu'), finish()],
            },
          ),
        );
        return (
          session,
          await f.characters.load('book'),
          await f.database.getNovelSegments('book'),
        );
      });
      addTearDown(() => tester.runAsync(f.close));
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NovelToolReviewDialog(
              session: data!.$1,
              roles: data.$2,
              segments: data.$3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final apply = find.widgetWithText(FilledButton, '应用修改');
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      final patchTitle = find.textContaining('修改标注 · 许宁');
      await tester.ensureVisible(patchTitle);
      await tester.tap(patchTitle);
      await tester.pumpAndSettle();
      expect(find.textContaining('修改依赖新增人物'), findsOneWidget);
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      final addTitle = find.text('补人 · 许宁');
      await tester.ensureVisible(addTitle);
      await tester.tap(addTitle);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
