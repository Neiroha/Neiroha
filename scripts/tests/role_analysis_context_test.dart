import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/role_analysis_checkpoint.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';
import 'support/fake_structured_llm.dart';
import 'support/novel_fixture.dart';
import 'support/role_skill_fixture.dart';

Map<String, Object?> plan() => {
  'characters': [
    {
      'name': '林舟',
      'aliases': ['小林'],
      'description': '青年',
      'identityKind': 'named',
    },
  ],
  'scene': {
    'firstPersonName': '小林',
    'presentCharacterNames': ['林舟'],
    'nestedNarratorNames': [],
    'messageChannels': ['spoken'],
    'evidence': '自述姓名',
  },
};
Map<String, Object?> labels(Map<String, dynamic> input, String review) => {
  'labels': [
    for (final s in input['segments'] as List)
      {
        'id': s['id'],
        'characterName': '林舟',
        'kind': 'dialogue',
        'review': review,
        'reason': '上下文',
      },
  ],
  'sceneSummary': '林舟在交谈。',
};

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late RoleAnalysisService service;
  late db.TtsProvider provider;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    characters = CharacterRepository(database);
    service = RoleAnalysisService(
      database,
      characters,
      AnnotationRepository(database),
      TtsQueueService.instance,
      loadSkill: loadTestRoleSkill,
    );
    provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
  });
  tearDown(() async {
    service.dispose();
    await database.close();
  });

  test(
    'scene IDs, both sides of context and independent doubts reach the reviewer',
    () async {
      var reviews = 0;
      final client = FakeStructuredLlm((stage, input, token) async {
        if (stage.contains('planCast')) {
          expect(
            input['structure']['segmentationVersion'],
            NovelSemanticSegmenter.version,
          );
          return plan();
        }
        final id = (input['roster'] as List).single['id'];
        expect(input['sceneState']['firstPersonId'], id);
        if (stage == 'novel_labelChunk') {
          expect(input, contains('followingContext'));
          expect(input, contains('precedingContext'));
          expect(input['segments'][0]['structure'], isNotNull);
          return labels(input, 'pending');
        }
        reviews++;
        expect(input['segments'][0]['existingLabel']['review'], 'pending');
        expect(input['doubts'][0]['code'], 'model_uncertainty');
        return labels(input, 'inferred');
      });
      await service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
      );
      final first = (await service.checkpoints.load('book', 'book-chapter'))!;
      expect(
        first.scene.firstPersonId,
        (await characters.load('book')).characters.single.id,
      );
      // Recreate the service to verify durable scene identity across a resume.
      service.dispose();
      service = RoleAnalysisService(
        database,
        characters,
        AnnotationRepository(database),
        TtsQueueService.instance,
        loadSkill: loadTestRoleSkill,
      );
      await service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
        confirmRoster: true,
        batchSize: 1,
      );
      final done = (await service.checkpoints.load('book', 'book-chapter'))!;
      expect(done.stage, 'completed');
      expect(done.reviewedSegments, 3);
      expect(reviews, 3);
      expect(done.segmentationVersion, NovelSemanticSegmenter.version);
    },
  );

  test('invalid scene identity rolls back a newly proposed roster', () async {
    final client = FakeStructuredLlm(
      (stage, input, token) async => {
        ...plan(),
        'scene': {...plan()['scene'] as Map, 'firstPersonName': '不存在的人物'},
      },
    );
    await expectLater(
      service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
      ),
      throwsFormatException,
    );
    expect((await characters.load('book')).characters, isEmpty);
  });

  test(
    'resuming a different segmentation version is rejected before inference',
    () async {
      final skill = await loadTestRoleSkill();
      await service.checkpoints.save(
        'book',
        'book-chapter',
        RoleAnalysisCheckpoint(
          signature: 'old',
          providerId: provider.id,
          model: 'fake',
          skillDigest: skill.digest,
          segmentationVersion: 'semantic-old',
        ),
      );
      var called = false;
      final client = FakeStructuredLlm((stage, input, token) async {
        called = true;
        return plan();
      });
      await expectLater(
        service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: provider,
          model: 'fake',
          client: client,
        ),
        throwsStateError,
      );
      expect(called, isFalse);
    },
  );

  test(
    'scene carry-over follows chapter order and never imports a future chapter',
    () async {
      for (final (id, order) in [('past', -1), ('future', 1)]) {
        await database.insertNovelChapter(
          db.NovelChaptersCompanion(
            id: Value(id),
            projectId: const Value('book'),
            orderIndex: Value(order),
            title: Value(id),
          ),
        );
        await service.checkpoints.save(
          'book',
          id,
          RoleAnalysisCheckpoint(
            signature: id,
            providerId: provider.id,
            model: 'fake',
            stage: 'completed',
            sceneSummary: id,
          ),
        );
      }
      expect(
        await service.checkpoints.recentScene('book', 'book-chapter'),
        'past',
      );
    },
  );

  test(
    'oversized input is rejected before a model call is charged to the budget',
    () async {
      await characters.saveCharacter(
        projectId: 'book',
        name: '过长档案',
        description: List.filled(65001, 'x').join(),
      );
      var called = false;
      final client = FakeStructuredLlm((stage, input, token) async {
        called = true;
        return plan();
      });
      await expectLater(
        service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: provider,
          model: 'fake',
          client: client,
        ),
        throwsStateError,
      );
      expect(called, isFalse);
      expect(
        (await service.checkpoints.load('book', 'book-chapter'))!.calls,
        0,
      );
    },
  );

  test(
    'long semantic rows use adaptive batches without truncating editable text',
    () async {
      for (final row in await database.getNovelSegments('book')) {
        await (database.update(
          database.novelSegments,
        )..where((t) => t.id.equals(row.id))).write(
          db.NovelSegmentsCompanion(
            segmentText: Value(List.filled(10000, '甲').join()),
          ),
        );
      }
      final sizes = <int>[];
      final client = FakeStructuredLlm((stage, input, token) async {
        if (stage.contains('planCast')) return plan();
        sizes.add(
          (input['segments'] as List).fold(
            0,
            (sum, row) => sum + (row['text'] as String).length,
          ),
        );
        return labels(input, 'inferred');
      });
      await service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
      );
      await service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
        confirmRoster: true,
      );
      expect(sizes, [20000, 10000]);
      expect(
        (await service.checkpoints.load('book', 'book-chapter'))!.stage,
        'completed',
      );
    },
  );
}
