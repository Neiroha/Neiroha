import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/novel/role_analysis_checkpoint.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';
import 'measured_role_llm.dart';
import 'novel_fixture.dart';

Future<List<RoleAnalysisCheckpoint>> runEvaluationChapters({
  required db.AppDatabase database,
  required CharacterRepository characters,
  required RoleAnalysisService Function() createService,
  required MeasuredRoleLlm client,
  required List<String> chapters,
  required String fixtureId,
  required String key,
  required String model,
  required int maxCallsPerChapter,
}) async {
  await seedNovelFixture(database);
  await database.delete(database.novelSegments).go();
  const projectId = 'book';
  final provider = (await database.getAllProviders())
      .firstWhere((p) => p.id == 'test-provider')
      .copyWith(baseUrl: 'https://api.openai.com/v1', apiKey: key);
  final rows = <db.NovelSegmentsCompanion>[];
  final chapterIds = <String>[];
  for (final (index, text) in chapters.indexed) {
    final chapterId = index == 0 ? 'book-chapter' : 'book-chapter-$index';
    chapterIds.add(chapterId);
    await database
        .into(database.novelChapters)
        .insertOnConflictUpdate(
          db.NovelChaptersCompanion.insert(
            id: chapterId,
            projectId: projectId,
            orderIndex: index,
            title: 'Chapter ${index + 1}',
            rawText: Value(text),
          ),
        );
    for (final (order, segment) in splitNovelText(text).indexed) {
      final row = db.NovelSegmentsCompanion.insert(
        id: '$fixtureId-${rows.length}',
        projectId: projectId,
        chapterId: chapterId,
        globalIndex: rows.length,
        orderIndex: order,
        segmentText: segment.text,
        segmentType: Value(segment.type),
      );
      rows.add(row);
      await database.insertNovelSegment(row);
    }
  }
  final checkpoints = <RoleAnalysisCheckpoint>[];
  for (final chapterId in chapterIds) {
    final before = (await characters.load(projectId)).annotations.length;
    var service = createService();
    try {
      await service.run(
        projectId: projectId,
        chapterId: chapterId,
        provider: provider,
        model: model,
        client: client,
        maxCalls: 1,
      );
      expect(
        (await service.checkpoints.load(projectId, chapterId))!.stage,
        'rosterReview',
      );
      expect((await characters.load(projectId)).annotations, hasLength(before));
      service.dispose();
      service = createService();
      await service.run(
        projectId: projectId,
        chapterId: chapterId,
        provider: provider,
        model: model,
        client: client,
        confirmRoster: true,
        maxCalls: maxCallsPerChapter - 1,
      );
      final checkpoint = (await service.checkpoints.load(
        projectId,
        chapterId,
      ))!;
      expect(checkpoint.stage, 'completed', reason: checkpoint.error);
      checkpoints.add(checkpoint);
    } finally {
      service.dispose();
    }
  }
  final saved = await database.getNovelSegments(projectId);
  expect(
    saved.map((s) => [s.id, s.segmentText]),
    rows.map((r) => [r.id.value, r.segmentText.value]),
  );
  expect(saved.map((s) => s.segmentText).join(), chapters.join());
  expect(
    (await database.getNovelChapters(projectId)).map((c) => c.rawText),
    chapters,
  );
  return checkpoints;
}
