import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/novel_roles/annotation_editor.dart';
import 'package:neiroha/presentation/widgets/novel_roles/review_panel.dart';
import 'package:neiroha/presentation/widgets/novel_roles/review_reader.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    await CharacterRepository(
      database,
    ).saveCharacter(projectId: 'book', name: '林舟');
  });
  tearDown(() => database.close());

  Future<void> pump(
    WidgetTester tester,
    Widget widget, {
    double width = 340,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: widget),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'role review panel fits narrow windows and shows editable role data',
    (tester) async {
      final roles = await CharacterRepository(database).load('book');
      final segments = await database.getNovelSegments('book');
      await pump(
        tester,
        NovelRoleReviewPanel(
          projectId: 'book',
          chapterId: 'book-chapter',
          roles: roles,
          assets: await database.getAllVoiceAssets(),
          segments: segments,
          selected: segments.first,
          beforeChange: () {},
          onSelect: (_) {},
          onPreview: (_) {},
        ),
      );
      expect(find.textContaining('林舟'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'manual speaker assignment persists, locks and keeps original text',
    (tester) async {
      final roles = await CharacterRepository(database).load('book');
      final segments = await database.getNovelSegments('book');
      await pump(
        tester,
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: NovelAnnotationEditor(
              segment: segments.first,
              roles: roles,
              segments: segments,
              assets: await database.getAllVoiceAssets(),
              beforeChange: () {},
              onPreview: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('未确定人物'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('林舟').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('应用修改'));
      await tester.tap(find.text('应用修改'));
      await tester.pumpAndSettle();
      final saved = await CharacterRepository(database).load('book');
      expect(
        saved.annotations[segments.first.id]!.characterId,
        roles.characters.single.id,
      );
      expect(saved.annotations[segments.first.id]!.locked, isTrue);
      expect(
        (await database.getNovelSegments('book')).first.segmentText,
        segments.first.segmentText,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'review reader separates character, cache and active playback signals',
    (tester) async {
      final roles = await CharacterRepository(database).load('book');
      final segments = await database.getNovelSegments('book');
      final selected = <String>[];
      await pump(
        tester,
        NovelRoleReviewReader(
          project: (await database.getNovelProjectById('book'))!,
          roles: roles,
          segments: segments,
          cacheStates: {segments.first.id: 'stale'},
          playingIndex: segments.first.globalIndex,
          onSelect: (s) => selected.add(s.id),
          onPreview: (_) {},
        ),
      );
      await tester.tap(find.text(segments.first.segmentText));
      await tester.pump(const Duration(milliseconds: 350));
      expect(selected, [segments.first.id]);
      expect(find.byTooltip('音频需要重新生成'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
