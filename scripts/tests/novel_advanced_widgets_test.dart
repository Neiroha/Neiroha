import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/task_profile_repository.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/novel_roles/structure_tools.dart';
import 'package:neiroha/presentation/widgets/novel_roles/task_profiles_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
  });
  tearDown(() => database.close());
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'text range dialog splits actual source and preserves every character',
    (tester) async {
      final source = (await database.getNovelSegments('book')).first;
      var stopped = false;
      await pump(
        tester,
        NovelStructureTools(
          segment: source,
          segments: await database.getNovelSegments('book'),
          beforeChange: () => stopped = true,
          onSelect: (_) {},
        ),
      );
      await tester.tap(find.text('拆分正文'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final at = source.segmentText.indexOf('𠮷');
      field.controller!.selection = TextSelection(
        baseOffset: at,
        extentOffset: at + 2,
      );
      await tester.tap(find.widgetWithText(FilledButton, '拆分正文'));
      await tester.pumpAndSettle();
      final rows = await database.getNovelSegmentsForChapter('book-chapter');
      expect(rows.take(3).map((s) => s.segmentText).join(), source.segmentText);
      expect(rows[1].segmentText, '𠮷');
      expect(stopped, true);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets(
    'task dialog switches text and audio protocols without losing persisted binding',
    (tester) async {
      await pump(tester, const TaskProfilesDialog(projectId: 'book'));
      await tester.tap(find.byType(DropdownButtonFormField<ModelTask>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('小说朗读').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<ServiceRoute>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('speech').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'custom-speaker');
      await tester.enterText(find.byType(TextField).at(1), 'custom/tts');
      await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      final profile = (await TaskProfileRepository(
        database,
      ).load('book')).single;
      expect(profile.task, ModelTask.synthesis);
      expect(profile.route, ServiceRoute.speech);
      expect(profile.model, 'custom-speaker');
      expect(profile.endpointPath, 'custom/tts');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );
}
