import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_direction_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_direction.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'support/fake_structured_llm.dart';
import 'support/novel_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late RoleDirectionService service;
  late db.TtsProvider provider;
  late String character;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    characters = CharacterRepository(database);
    character = await characters.saveCharacter(
      projectId: 'book',
      name: '众船员',
      identityKind: CharacterIdentityKind.group,
    );
    service = RoleDirectionService(
      database,
      TtsQueueService.instance,
      loadSkill: loadTestRoleSkill,
    );
    provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
  });
  tearDown(() => database.close());
  FakeStructuredLlm reply(String id, String value) => FakeStructuredLlm(
    (stage, input, _) async => {
      'suggestions': [
        {'id': id, 'value': value, 'reason': '符合当前场景'},
      ],
    },
  );
  Future<RoleDirectionProposal> propose(
    RoleDirectionTask task,
    FakeStructuredLlm client,
  ) => service.propose(
    projectId: 'book',
    chapterId: 'book-chapter',
    task: task,
    provider: provider,
    model: 'fake',
    cancellation: TtsCancelToken(),
    client: client,
  );

  test(
    'casting requires review, preserves existing bindings and copies no credentials',
    () async {
      final bound = await characters.saveCharacter(
        projectId: 'book',
        name: '已绑定',
      );
      await characters.bindVoice(
        projectId: 'book',
        characterId: bound,
        voiceAssetId: 'voice-a',
      );
      final client = FakeStructuredLlm((stage, input, _) async {
        expect(input['targetIds'], [character]);
        expect((input['characters'] as List).first['kind'], 'group');
        expect(input.toString().contains('apiKey'), false);
        return {
          'suggestions': [
            {'id': character, 'value': 'voice-b', 'reason': '群体音色'},
          ],
        };
      });
      final suggestion = await propose(RoleDirectionTask.casting, client);
      expect((await characters.load('book')).bindings, hasLength(1));
      await service.apply(suggestion, {character});
      final bindings = (await characters.load('book')).bindings;
      expect(
        bindings.singleWhere((b) => b.characterId == bound).voiceAssetId,
        'voice-a',
      );
      expect(
        bindings.singleWhere((b) => b.characterId == character).voiceAssetId,
        'voice-b',
      );
    },
  );

  test(
    'unknown voice or duplicate target fails before any binding writes',
    () async {
      await expectLater(
        propose(RoleDirectionTask.casting, reply(character, 'made-up')),
        throwsFormatException,
      );
      expect((await characters.load('book')).bindings, isEmpty);
    },
  );

  test(
    'stale casting proposal cannot overwrite a newer manual binding',
    () async {
      final suggestion = await propose(
        RoleDirectionTask.casting,
        reply(character, 'voice-b'),
      );
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-a',
      );
      await expectLater(
        service.apply(suggestion, {character}),
        throwsStateError,
      );
      expect(
        (await characters.load('book')).bindings.single.voiceAssetId,
        'voice-a',
      );
    },
  );

  test(
    'tone only targets unconfirmed unlocked labels and never changes text or voice',
    () async {
      final segments = await database.getNovelSegments('book');
      await AnnotationRepository(database).apply('book', [
        for (final s in segments)
          SegmentAnnotation(
            segmentId: s.id,
            projectId: 'book',
            textRevision: novelTextRevision(s.segmentText),
            characterId: character,
            kind: NovelSegmentKind.dialogue,
            reviewState: NovelReviewState.inferred,
          ),
      ], fromAi: true);
      await AnnotationRepository(database).apply('book', [
        SegmentAnnotation(
          segmentId: segments[0].id,
          projectId: 'book',
          characterId: character,
          textRevision: novelTextRevision(segments[0].segmentText),
          kind: NovelSegmentKind.dialogue,
        ),
      ]);
      final suggestion = await propose(
        RoleDirectionTask.tone,
        FakeStructuredLlm((stage, input, _) async {
          expect(input['targetIds'], [segments[1].id, segments[2].id]);
          return {
            'suggestions': [
              {'id': segments[1].id, 'value': '低声、迟疑', 'reason': '上下文'},
            ],
          };
        }),
      );
      expect(await service.apply(suggestion, {segments[1].id}), 1);
      final roles = await characters.load('book');
      expect(roles.annotations[segments[0].id]!.instruction, isNull);
      expect(roles.annotations[segments[1].id]!.instruction, '低声、迟疑');
      expect(roles.annotations[segments[1].id]!.characterId, character);
      expect(await database.getNovelSegments('book'), segments);
    },
  );
}
