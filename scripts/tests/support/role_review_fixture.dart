import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/ai/protocols/openai/llm_chat_adapter.dart';
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_review_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'novel_fixture.dart';
import 'role_skill_fixture.dart';

const reviewTexts = [
  '门卫老周摘下帽子说：“我就是周柏，这不是另一个人。”',
  '许宁推开门：“我是许宁，来接你们。”',
  '“先等等。”林舟说。',
];

Map<String, Object?> reviewSnapshotJson(NovelRoleSnapshot s) => {
  'characters': [
    for (final c in s.characters)
      {
        'id': c.id,
        'name': c.name,
        'aliases': c.aliases,
        'identityKind': c.identityKind.name,
      },
  ],
  'labels': [
    for (final a in s.annotations.values)
      {
        'id': a.segmentId,
        'characterId': a.characterId,
        'kind': a.kind.name,
        'reviewState': a.reviewState.name,
        'locked': a.locked,
        'reason': a.reason,
      },
  ],
};

class RoleReviewFixture {
  final database = db.AppDatabase.forTesting(NativeDatabase.memory());
  late db.TtsProvider provider;
  late RoleReviewService service;
  CharacterRepository get characters => CharacterRepository(database);
  Future<void> init() async {
    await seedNovelFixture(database);
    for (final (id, name) in [('guard', '老周'), ('zhou', '周柏'), ('lin', '林舟')]) {
      await database
          .into(database.novelCharacters)
          .insert(
            db.NovelCharactersCompanion(
              id: Value(id),
              projectId: const Value('book'),
              name: Value(name),
            ),
          );
    }
    for (var i = 0; i < reviewTexts.length; i++) {
      await (database.update(database.novelSegments)
            ..where((t) => t.id.equals('sentence-$i')))
          .write(db.NovelSegmentsCompanion(segmentText: Value(reviewTexts[i])));
      await AnnotationRepository(database).apply('book', [
        SegmentAnnotation(
          segmentId: 'sentence-$i',
          projectId: 'book',
          textRevision: novelTextRevision(reviewTexts[i]),
          characterId: i == 0
              ? 'guard'
              : i == 2
              ? 'zhou'
              : null,
          kind: i == 1 ? NovelSegmentKind.narrator : NovelSegmentKind.dialogue,
          reviewState: NovelReviewState.inferred,
        ),
      ], fromAi: true);
    }
    provider = (await database.getAllProviders()).firstWhere(
      (p) => p.id == 'test-provider',
    );
    service = RoleReviewService(
      database,
      TtsQueueService.instance,
      loadSkill: loadTestRoleSkill,
    );
  }

  Future<void> close() async {
    service.dispose();
    await database.close();
  }
}

class ReviewLlm extends LlmChatAdapter {
  ReviewLlm(this.reply, {this.usage = const {'total_tokens': 100}})
    : super(baseUrl: 'http://localhost', apiKey: '', modelName: 'fake');
  final Future<Map<String, dynamic>> Function(
    Map<String, dynamic>,
    TtsCancelToken,
  )
  reply;
  final Map<String, dynamic> usage;
  int calls = 0;
  final systemPrompts = <String>[];
  int? outputLimit;
  bool? fallback;
  @override
  Future<LlmStructuredResult> structured({
    required List<LlmChatMessage> messages,
    required String schemaName,
    required Map<String, Object?> schema,
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
    bool allowFormatFallback = true,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    calls++;
    systemPrompts.add(messages.first.content);
    outputLimit = maxOutputTokens;
    fallback = allowFormatFallback;
    return LlmStructuredResult(
      await reply(
        jsonDecode(messages.last.content) as Map<String, dynamic>,
        cancellation,
      ),
      finishReason: 'stop',
      usage: usage,
    );
  }
}

Map<String, dynamic> anchor(int i, [String? quote]) => {
  'segmentId': 'sentence-$i',
  'quote': quote ?? reviewTexts[i],
};
Map<String, dynamic> newPerson() => {
  'action': 'propose_character',
  'key': 'xu',
  'name': '许宁',
  'aliases': <String>[],
  'description': '来接众人的访客',
  'identityKind': 'named',
  'reason': '人物在正文中自报姓名',
  'evidence': [anchor(1)],
};
Map<String, dynamic> patch(int i, String? ref, {String? key}) => {
  'action': 'propose_patch',
  'key': key ?? 'patch$i',
  'segmentId': 'sentence-$i',
  'characterRef': ref,
  'kind': 'dialogue',
  'reason': '按明确提示语归属',
  'evidence': [anchor(i)],
};
Map<String, dynamic> mergePeople() => {
  'action': 'propose_merge',
  'key': 'merge',
  'fromId': 'guard',
  'intoId': 'zhou',
  'reason': '同一人自报姓名',
  'evidence': [anchor(0)],
};
Map<String, dynamic> finish() => {'action': 'finish', 'reason': '证据足够，等待用户审阅'};
