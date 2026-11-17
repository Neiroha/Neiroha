import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/novel/text_role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'support/role_review_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  late RoleReviewFixture f;
  setUp(() async {
    f = RoleReviewFixture();
    await f.init();
  });
  tearDown(() => f.close());
  test(
    'shared text analysis preserves every UTF-16 unit and carries user intent into labeling/review',
    () async {
      const text = ' \r\n我叫林舟𠮷。\n林舟说：“先别走👋。”\n';
      const intent = '保留原文，按人物分声线；转述由讲述者朗读。';
      final client = ReviewLlm((input, token) async {
        expect(input['userFeedback'], intent);
        if (input.containsKey('chapterExcerpt')) {
          return {
            'characters': [
              {
                'name': '林舟',
                'aliases': <String>[],
                'description': '讲述人',
                'identityKind': 'named',
              },
            ],
            'scene': {
              'firstPersonName': '林舟',
              'presentCharacterNames': ['林舟'],
              'nestedNarratorNames': <String>[],
              'messageChannels': ['spoken'],
              'evidence': '自我介绍',
            },
          };
        }
        return {
          'labels': [
            for (final s in input['segments'] as List)
              {
                'id': s['id'],
                'characterName': '林舟',
                'kind': 'dialogue',
                'review': 'inferred',
                'reason': '发言提示语',
              },
          ],
          'sceneSummary': '林舟在说话',
        };
      });
      final plan =
          await TextRoleAnalysisService(
            TtsQueueService.instance,
            loadSkill: () async => (await loadTestRoleSkill()).customize(
              'intent-profile',
              {'planner': 'CUSTOM_PLANNER_FOR_INITIAL_INTENT'},
            ),
          ).analyze(
            text: text,
            intent: intent,
            provider: f.provider,
            model: 'fake',
            cancellation: TtsCancelToken(),
            client: client,
          );
      expect(plan.units.map((u) => u.text).join(), text);
      expect(client.systemPrompts.first, 'CUSTOM_PLANNER_FOR_INITIAL_INTENT');
      expect(plan.units.first.start, 0);
      expect(plan.units.last.end, text.length);
      expect(
        plan.units.every((u) => u.review != NovelReviewState.confirmed),
        isTrue,
      );
      expect(plan.calls, lessThanOrEqualTo(40));
      expect(await f.database.getAllNovelProjects(), hasLength(2));
    },
  );
  test(
    'cancelled or oversized work sends no requests and creates no reader project',
    () async {
      final client = ReviewLlm(
        (_, _) async => throw StateError('must not call'),
      );
      final token = TtsCancelToken()..cancel();
      final service = TextRoleAnalysisService(
        TtsQueueService.instance,
        loadSkill: loadTestRoleSkill,
      );
      await expectLater(
        service.analyze(
          text: '林舟说：“你好。”',
          intent: '',
          provider: f.provider,
          model: 'fake',
          cancellation: token,
          client: client,
        ),
        throwsA(isA<TtsCancelledException>()),
      );
      await expectLater(
        service.analyze(
          text: List.filled(64001, '长').join(),
          intent: '',
          provider: f.provider,
          model: 'fake',
          cancellation: TtsCancelToken(),
          client: client,
        ),
        throwsArgumentError,
      );
      expect(client.calls, 0);
    },
  );
}
