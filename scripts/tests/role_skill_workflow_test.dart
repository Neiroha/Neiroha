import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/role_analysis_checkpoint.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/novel/role_direction_service.dart';
import 'package:neiroha/data/services/novel/role_skill_repository.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'package:neiroha/domain/novel/role_direction.dart';

import 'support/fake_structured_llm.dart';
import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late RoleAnalysisService service;
  late db.TtsProvider provider;
  late String document;
  Future<NovelRoleSkill> load() async => NovelRoleSkill.parse(document);
  setUp(() async {
    document = File(RoleSkillRepository.assetPath).readAsStringSync();
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    characters = CharacterRepository(database);
    service = RoleAnalysisService(
      database,
      characters,
      AnnotationRepository(database),
      TtsQueueService.instance,
      loadSkill: load,
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
    'changed content at the same version blocks resume before another call',
    () async {
      var calls = 0;
      final client = FakeStructuredLlm((stage, input, token) async {
        calls++;
        return {
          'characters': [
            {
              'name': '林舟',
              'aliases': <String>[],
              'description': '青年',
              'identityKind': 'named',
            },
          ],
        };
      });
      await service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: provider,
        model: 'fake',
        client: client,
      );
      final saved = (await service.checkpoints.load('book', 'book-chapter'))!;
      expect(saved.skillDigest, (await load()).digest);
      expect(saved.skillVersion, (await load()).version);
      document = document.replaceFirst(
        'Assign labels',
        'Assign checked labels',
      );
      await expectLater(
        service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: provider,
          model: 'fake',
          client: client,
          confirmRoster: true,
        ),
        throwsStateError,
      );
      expect(calls, 1);
      expect((await characters.load('book')).annotations, isEmpty);
    },
  );
  test(
    'legacy checkpoint remains readable but cannot silently resume',
    () async {
      await service.checkpoints.save(
        'book',
        'book-chapter',
        RoleAnalysisCheckpoint(
          signature: 'legacy',
          providerId: provider.id,
          model: 'fake',
        ),
      );
      var called = false;
      final client = FakeStructuredLlm((stage, input, token) async {
        called = true;
        return {};
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
    'director rejects a pending voice proposal after the skill changes',
    () async {
      final character = await characters.saveCharacter(
        projectId: 'book',
        name: '林舟',
      );
      final director = RoleDirectionService(
        database,
        TtsQueueService.instance,
        loadSkill: load,
      );
      final proposal = await director.propose(
        projectId: 'book',
        chapterId: 'book-chapter',
        task: RoleDirectionTask.casting,
        provider: provider,
        model: 'fake',
        cancellation: TtsCancelToken(),
        client: FakeStructuredLlm(
          (stage, input, token) async => {
            'suggestions': [
              {'id': character, 'value': 'voice-a', 'reason': '角色声线'},
            ],
          },
        ),
      );
      document = document.replaceFirst('1.0.0', '1.0.1');
      await expectLater(
        director.apply(proposal, {character}),
        throwsStateError,
      );
      expect((await characters.load('book')).bindings, isEmpty);
    },
  );
}
