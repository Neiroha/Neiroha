import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_analysis_checkpoint.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/novel/role_analysis_protocol.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/voice_resolver.dart';

import 'support/novel_fixture.dart';
import 'support/role_skill_fixture.dart';

class _Llm extends LlmChatAdapter {
  _Llm(this.reply)
    : super(baseUrl: 'http://localhost', apiKey: '', modelName: 'fake');
  final Future<Map<String, dynamic>> Function(
    String stage,
    Map<String, dynamic> input,
    TtsCancelToken cancellation,
  )
  reply;
  @override
  Future<LlmStructuredResult> structured({
    required List<LlmChatMessage> messages,
    required String schemaName,
    required Map<String, Object?> schema,
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async => LlmStructuredResult(
    await reply(
      schemaName,
      jsonDecode(messages.last.content) as Map<String, dynamic>,
      cancellation,
    ),
    finishReason: 'stop',
  );
}

Map<String, dynamic> _labels(Map<String, dynamic> input) => {
  'labels': [
    for (final s in input['segments'] as List)
      {
        'id': s['id'],
        'characterName': '林舟',
        'kind': 'dialogue',
        'review': 'inferred',
        'reason': '上下文',
      },
  ],
  'sceneSummary': '林舟正在交谈。',
};
const _roster = {
  'characters': [
    {
      'name': '林舟',
      'aliases': ['他', '小林'],
      'description': '青年',
    },
  ],
};

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late AnnotationRepository annotations;
  late RoleAnalysisService service;
  late db.TtsProvider provider;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    characters = CharacterRepository(database);
    annotations = AnnotationRepository(database);
    service = RoleAnalysisService(
      database,
      characters,
      annotations,
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
    'system and narrator labels retain identities; unknown claims need review',
    () async {
      final character = await characters.saveCharacter(
        projectId: 'book',
        name: '林舟',
      );
      final source = await database.getNovelSegments('book');
      final labels = RoleAnalysisProtocol.parseLabels(
        {
          'labels': [
            for (var i = 0; i < source.length; i++)
              {
                'id': source[i].id,
                'characterName': i == 2 ? '不存在的人物' : '林舟',
                'kind': i == 0 ? 'system' : 'narrator',
                'review': 'inferred',
                'reason': '归属证据',
              },
          ],
        },
        source,
        await characters.load('book'),
      );
      await annotations.apply('book', labels, fromAi: true);
      final stored = (await characters.load('book')).annotations;
      expect(stored[source[0].id]!.characterId, character);
      expect(stored[source[1].id]!.characterId, character);
      expect(stored[source[2].id]!.characterId, isNull);
      expect(stored[source[2].id]!.reviewState, NovelReviewState.conflict);
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-b',
      );
      final voice = NovelVoiceResolver.resolve(
        segmentId: source[0].id,
        chapterId: 'book-chapter',
        kind: NovelSegmentKind.system,
        roles: await characters.load('book'),
        availableVoiceIds: {'voice-a', 'voice-b'},
        narratorVoiceId: 'voice-a',
      );
      expect(voice.voiceAssetId, 'voice-b');
    },
  );
  Future<void> run(
    _Llm client, {
    bool resume = false,
    int budget = 12,
    int batchSize = 20,
  }) => service.run(
    projectId: 'book',
    chapterId: 'book-chapter',
    provider: provider,
    model: 'fake',
    confirmRoster: resume,
    client: client,
    maxCalls: budget,
    batchSize: batchSize,
  );

  test(
    'new chapter receives the completed scene while keeping work identities',
    () async {
      final role = await characters.saveCharacter(
        projectId: 'book',
        name: '林舟',
      );
      await service.checkpoints.save(
        'book',
        'previous-chapter',
        RoleAnalysisCheckpoint(
          signature: 'earlier text',
          providerId: provider.id,
          model: 'fake',
          stage: 'completed',
          sceneSummary: '林舟已抵达码头。',
        ),
      );
      final client = _Llm((stage, input, _) async {
        expect(input['recentScene'], '林舟已抵达码头。');
        if (stage.contains('planCast')) {
          expect((input['knownCharacters'] as List).single['id'], role);
          return Map.of(_roster);
        }
        expect((input['roster'] as List).single['id'], role);
        return _labels(input);
      });
      await run(client);
      await run(client, resume: true);
      expect((await characters.load('book')).characters.single.id, role);
    },
  );

  test(
    'planner pauses for roster review, then labels IDs without rewriting text',
    () async {
      final calls = <String>[];
      final client = _Llm((stage, input, _) async {
        calls.add(stage);
        return stage.contains('planCast') ? Map.of(_roster) : _labels(input);
      });
      final original = (await database.getNovelSegments(
        'book',
      )).map((s) => s.segmentText).toList();
      await run(client);
      expect(
        (await service.checkpoints.load('book', 'book-chapter'))!.stage,
        'rosterReview',
      );
      expect((await characters.load('book')).characters.single.aliases, ['小林']);
      expect((await characters.load('book')).annotations, isEmpty);
      await run(client, resume: true);
      final saved = await service.checkpoints.load('book', 'book-chapter');
      expect(saved!.stage, 'completed');
      expect(saved.nextSegment, 3);
      expect(saved.calls, 2);
      expect(
        (await database.getNovelSegments('book')).map((s) => s.segmentText),
        original,
      );
      expect((await characters.load('book')).annotations, hasLength(3));
      expect(calls, ['novel_planCast', 'novel_labelChunk']);
    },
  );

  test(
    'locked/confirmed manual sentence is omitted from model requests',
    () async {
      final character = await characters.saveCharacter(
        projectId: 'book',
        name: '林舟',
      );
      final s = (await database.getNovelSegments('book')).first;
      await annotations.apply('book', [
        SegmentAnnotation(
          segmentId: s.id,
          projectId: 'book',
          textRevision: novelTextRevision(s.segmentText),
          characterId: character,
          locked: true,
        ),
      ]);
      final client = _Llm((stage, input, _) async {
        if (stage.contains('planCast')) return Map.of(_roster);
        expect(
          (input['segments'] as List).any((row) => row['id'] == s.id),
          isFalse,
        );
        return _labels(input);
      });
      await run(client);
      await run(client, resume: true);
      expect((await characters.load('book')).annotations[s.id]!.locked, isTrue);
    },
  );

  test('a bounded run checkpoints and resumes from its next batch', () async {
    final client = _Llm(
      (stage, input, _) async =>
          stage.contains('planCast') ? Map.of(_roster) : _labels(input),
    );
    await run(client);
    await run(client, resume: true, budget: 1, batchSize: 1);
    var saved = (await service.checkpoints.load('book', 'book-chapter'))!;
    expect(saved.stage, 'paused');
    expect(saved.nextSegment, 1);
    await run(client, resume: true, budget: 1, batchSize: 1);
    saved = (await service.checkpoints.load('book', 'book-chapter'))!;
    expect(saved.nextSegment, 2);
    await run(client, resume: true, budget: 1, batchSize: 1);
    expect(
      (await service.checkpoints.load('book', 'book-chapter'))!.stage,
      'completed',
    );
  });

  test('malformed labels fail atomically and retry can recover', () async {
    var broken = true;
    final client = _Llm((stage, input, _) async {
      if (stage.contains('planCast')) return Map.of(_roster);
      final labels = _labels(input);
      if (broken) {
        (labels['labels'] as List)[1]['id'] =
            (labels['labels'] as List)[0]['id'];
      }
      return labels;
    });
    await run(client);
    await expectLater(run(client, resume: true), throwsFormatException);
    expect((await characters.load('book')).annotations, isEmpty);
    expect(
      (await service.checkpoints.load('book', 'book-chapter'))!.stage,
      'failed',
    );
    broken = false;
    await run(client, resume: true);
    expect(
      (await service.checkpoints.load('book', 'book-chapter'))!.stage,
      'completed',
    );
  });

  test(
    'pause cancels an in-flight model request and retains a resumable checkpoint',
    () async {
      final started = Completer<void>();
      final client = _Llm((stage, input, token) async {
        if (stage.contains('planCast')) return Map.of(_roster);
        started.complete();
        final cancelled = Completer<Map<String, dynamic>>();
        final remove = token.onCancel(
          () => cancelled.completeError(const TtsCancelledException()),
        );
        return cancelled.future.whenComplete(remove);
      });
      await run(client);
      final running = run(client, resume: true);
      await started.future;
      service.pause('book');
      await running;
      final saved = (await service.checkpoints.load('book', 'book-chapter'))!;
      expect(saved.stage, 'paused');
      expect(saved.nextSegment, 0);
      expect(service.isRunning('book'), isFalse);
    },
  );
}
