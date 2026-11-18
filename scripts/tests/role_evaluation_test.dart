import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/domain/novel/role_models.dart';

void main() {
  test(
    'gold speaker alternatives count once and reject unrelated speakers',
    () {
      final result = RoleEvaluation.evaluate(
        text: '甲乙丙',
        gold: [
          {
            'match': '甲',
            'category': '对话',
            'speaker': ['周航', '老许'],
          },
          {
            'match': '乙',
            'category': '对话',
            'speaker': ['周航', '老许'],
          },
          {
            'match': '丙',
            'category': '对话',
            'speaker': ['周航', '老许'],
          },
        ],
        predictions: [
          const RolePrediction(0, 1, NovelSegmentKind.dialogue, '老许'),
          const RolePrediction(1, 2, NovelSegmentKind.dialogue, '外人'),
          const RolePrediction(2, 3, NovelSegmentKind.narrator, '周航'),
        ],
      );
      expect(result.speakerTotal, 3);
      expect(result.speakerCorrect, 1);
      expect(result.failures, ['乙', '丙']);
    },
  );
  test(
    'evaluation honors aliases, alternate categories and counts wrong speakers',
    () {
      final result = RoleEvaluation.evaluate(
        text: '标题。你好！再见。',
        roster: [
          {
            'name': '林舟',
            'aliases': ['小林'],
          },
        ],
        gold: [
          {
            'match': '标题',
            'category': ['系统', '旁白'],
          },
          {'match': '你好', 'category': '对话', 'speaker': '林舟'},
          {'match': '再见', 'category': '对话', 'speaker': '林舟'},
        ],
        predictions: [
          const RolePrediction(0, 3, NovelSegmentKind.system, null),
          const RolePrediction(3, 6, NovelSegmentKind.dialogue, '小林'),
          const RolePrediction(6, 9, NovelSegmentKind.dialogue, '别人'),
        ],
      );
      expect(result.evaluated, 3);
      expect(result.categoryCorrect, 3);
      expect(result.speakerCorrect, 1);
      expect(result.speakerTotal, 2);
      expect(result.failures, ['再见']);
    },
  );
  test(
    'ambiguous gold is explicit and omitted or surrogate-split text is invalid',
    () {
      final result = RoleEvaluation.evaluate(
        text: '你好你好',
        gold: [
          {'match': '你好', 'category': '旁白'},
        ],
        predictions: [
          const RolePrediction(0, 4, NovelSegmentKind.narrator, null),
        ],
      );
      expect(result.evaluated, 0);
      expect(result.ambiguousGold, 1);
      expect(
        () => RoleEvaluation.evaluate(
          text: '𠮷🌸',
          gold: [],
          predictions: [
            const RolePrediction(0, 1, NovelSegmentKind.narrator, null),
            const RolePrediction(1, 4, NovelSegmentKind.narrator, null),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => RoleEvaluation.evaluate(
          text: '原文',
          gold: [],
          predictions: [
            const RolePrediction(0, 1, NovelSegmentKind.narrator, null),
          ],
        ),
        throwsFormatException,
      );
    },
  );
}
