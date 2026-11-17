import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_preferences.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'support/role_review_fixture.dart';

void main() {
  late RoleReviewFixture f;
  setUp(() async {
    f = RoleReviewFixture();
    await f.init();
  });
  tearDown(() => f.close());
  Future<RoleReviewSession> propose(List<Map<String, dynamic>> actions) =>
      f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        client: ReviewLlm(
          (input, token) async => {
            'actions': [...actions, finish()],
          },
        ),
      );
  Future<int> apply(RoleReviewSession s, Set<String> keys) =>
      f.service.repository.apply('book', 'book-chapter', s.id, keys);

  test(
    'accepted additions/merges/relabels are atomic and remain AI inferred',
    () async {
      for (final id in ['guard', 'zhou']) {
        await f.characters.bindVoice(
          projectId: 'book',
          characterId: id,
          voiceAssetId: 'voice-a',
        );
      }
      final s = await propose([newPerson(), mergePeople(), patch(1, 'new:xu')]);
      expect(
        await apply(s, {'xu', 'merge', 'patch1'}),
        greaterThanOrEqualTo(3),
      );
      final roles = await f.characters.load('book');
      expect(roles.characters.any((c) => c.id == 'guard'), isFalse);
      expect(
        roles.characters.firstWhere((c) => c.id == 'zhou').aliases,
        contains('老周'),
      );
      final xu = roles.characters.singleWhere((c) => c.name == '许宁');
      expect(roles.annotations['sentence-1']!.characterId, xu.id);
      expect(roles.annotations['sentence-0']!.characterId, 'zhou');
      expect(
        roles.annotations['sentence-1']!.reviewState,
        NovelReviewState.inferred,
      );
      expect(roles.bindings.single.voiceAssetId, 'voice-a');
      expect(
        (await f.database.getNovelSegments('book')).map((s) => s.segmentText),
        reviewTexts,
      );
      await expectLater(apply(s, {'xu'}), throwsStateError);
    },
  );

  test(
    'a dependent patch cannot secretly create an unselected character',
    () async {
      final s = await propose([newPerson(), patch(1, 'new:xu')]);
      await expectLater(apply(s, {'patch1'}), throwsFormatException);
      expect((await f.characters.load('book')).characters, hasLength(3));
      expect(
        (await f.service.repository.load('book', 'book-chapter'))!.status,
        'ready',
      );
    },
  );

  test(
    'new manual confirmation makes the entire saved proposal stale',
    () async {
      final s = await propose([newPerson(), patch(1, 'new:xu')]);
      await AnnotationRepository(f.database).apply('book', [
        SegmentAnnotation(
          segmentId: 'sentence-1',
          projectId: 'book',
          textRevision: novelTextRevision(reviewTexts[1]),
          characterId: 'lin',
          locked: true,
          kind: NovelSegmentKind.dialogue,
        ),
      ]);
      await expectLater(apply(s, {'xu', 'patch1'}), throwsStateError);
      final roles = await f.characters.load('book');
      expect(roles.characters, hasLength(3));
      expect(roles.annotations['sentence-1']!.characterId, 'lin');
      expect(roles.annotations['sentence-1']!.locked, isTrue);
    },
  );

  test(
    'text or bank edits invalidate captured evidence and voice state',
    () async {
      final s = await propose([patch(2, 'lin')]);
      await (f.database.update(f.database.novelSegments)
            ..where((t) => t.id.equals('sentence-2')))
          .write(const db.NovelSegmentsCompanion(segmentText: Value('正文已变更')));
      await expectLater(apply(s, {'patch2'}), throwsStateError);
    },
  );

  test('AI merges refuse locked identities and conflicting voices', () async {
    await AnnotationRepository(f.database).apply('book', [
      SegmentAnnotation(
        segmentId: 'sentence-0',
        projectId: 'book',
        textRevision: novelTextRevision(reviewTexts[0]),
        characterId: 'guard',
        locked: true,
      ),
    ]);
    await expectLater(
      propose([
        {'action': 'read_context', 'segmentId': 'sentence-0', 'radius': 0},
        mergePeople(),
      ]),
      throwsStateError,
    );
    expect(
      (await f.characters.load('book')).characters.any((c) => c.id == 'guard'),
      isTrue,
    );
  });

  test('changing bank membership invalidates a saved proposal', () async {
    final s = await propose([patch(2, 'lin')]);
    await (f.database.delete(
      f.database.voiceBankMembers,
    )..where((t) => t.voiceAssetId.equals('voice-a'))).go();
    await expectLater(apply(s, {'patch2'}), throwsStateError);
    expect(
      (await f.characters.load('book')).annotations['sentence-2']!.characterId,
      'zhou',
    );
  });

  test(
    'group identities and target fallback bindings cannot be forced into merges',
    () async {
      await f.characters.saveCharacter(
        projectId: 'book',
        id: 'guard',
        name: '老周',
        identityKind: CharacterIdentityKind.group,
      );
      await expectLater(propose([mergePeople()]), throwsStateError);
      await f.characters.saveCharacter(
        projectId: 'book',
        id: 'guard',
        name: '老周',
        identityKind: CharacterIdentityKind.named,
      );
      await f.characters.bindVoice(
        projectId: 'book',
        characterId: 'guard',
        voiceAssetId: 'voice-a',
      );
      await expectLater(propose([mergePeople()]), throwsStateError);
      expect((await f.characters.load('book')).bindings, hasLength(1));
    },
  );

  test('voice/style conflicts are not erased to force a merge', () async {
    await f.characters.bindVoice(
      projectId: 'book',
      characterId: 'guard',
      voiceAssetId: 'voice-a',
    );
    await f.characters.bindVoice(
      projectId: 'book',
      characterId: 'zhou',
      voiceAssetId: 'voice-b',
    );
    await RolePreferences(f.database).setStyle(
      projectId: 'book',
      characterId: 'guard',
      kind: NovelSegmentKind.dialogue,
      voiceAssetId: 'voice-a',
    );
    await expectLater(propose([mergePeople()]), throwsStateError);
    expect((await f.characters.load('book')).bindings, hasLength(3));
  });

  test(
    'a late binding validation failure rolls back earlier character creation',
    () async {
      for (final id in ['guard', 'zhou']) {
        await f.characters.bindVoice(
          projectId: 'book',
          characterId: id,
          voiceAssetId: 'voice-a',
        );
      }
      // Simulate an imported bank missing an old voice membership.
      await (f.database.delete(
        f.database.voiceBankMembers,
      )..where((t) => t.voiceAssetId.equals('voice-a'))).go();
      final s = await propose([newPerson(), mergePeople()]);
      await expectLater(apply(s, {'xu', 'merge'}), throwsArgumentError);
      final roles = await f.characters.load('book');
      expect(roles.characters, hasLength(3));
      expect(roles.characters.any((c) => c.id == 'guard'), isTrue);
      expect(roles.annotations['sentence-0']!.characterId, 'guard');
      expect(
        (await f.service.repository.load('book', 'book-chapter'))!.status,
        'ready',
      );
    },
  );
}
