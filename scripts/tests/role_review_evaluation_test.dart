import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/domain/novel/role_review_evaluation.dart';
import 'package:neiroha/domain/novel/role_models.dart';

void main() {
  const d = NovelSegmentKind.dialogue;
  test('review gains, damage and doubt metrics use only annotated gold', () {
    final before = [
      const RolePrediction(0, 1, d, '甲'),
      const RolePrediction(1, 2, d, '甲'),
      const RolePrediction(2, 3, d, '未知'),
    ];
    final after = [
      const RolePrediction(0, 1, d, '乙'),
      const RolePrediction(1, 2, d, '乙'),
      const RolePrediction(2, 3, d, '甲'),
    ];
    final result = RoleReviewEvaluation.compare(
      text: '甲乙丙',
      gold: [
        {'match': '甲', 'category': 'dialogue', 'speaker': '甲'},
        {'match': '乙', 'category': 'dialogue', 'speaker': '乙'},
      ],
      before: before,
      after: after,
      flagged: [(start: 0, end: 1), (start: 1, end: 2), (start: 2, end: 3)],
      roster: [
        {
          'name': '甲',
          'aliases': ['阿甲'],
        },
        {'name': '乙'},
      ],
      predictedCast: [
        {'name': '甲'},
        {'name': '阿甲'},
        {'name': '乙'},
        {'name': '路人'},
      ],
      runs: [before, after, before],
    );
    expect(result['corrected'], 1);
    expect(result['harmed'], 1);
    expect(result['netGain'], 0);
    expect(result['evaluated'], 2);
    expect(result['doubtPrecision'], .5);
    expect(result['doubtRecall'], 1);
    expect(result['characterRecall'], 1);
    expect(result['duplicateIdentities'], 1);
    expect(result['unmatchedPredictedIdentities'], 1);
    expect(result['runAgreement'], closeTo(1 / 3, .0001));
  });
  test(
    'ambiguous gold/identity matching and missing comparisons stay explicit',
    () {
      final labels = [const RolePrediction(0, 2, d, null)];
      final r = RoleReviewEvaluation.compare(
        text: '哈哈',
        gold: [
          {'match': '哈', 'category': 'dialogue'},
        ],
        before: labels,
        after: labels,
        roster: [
          {
            'name': '甲',
            'aliases': ['老王'],
          },
          {
            'name': '乙',
            'aliases': ['老王'],
          },
        ],
        predictedCast: [
          {'name': '老王'},
        ],
      );
      expect(r['ambiguousGoldExcluded'], 1);
      expect(r['ambiguousPredictedIdentities'], 1);
      expect(r['characterRecall'], 0);
      expect(r['runAgreement'], isNull);
      expect(r['doubtPrecision'], isNull);
      expect(
        () => RoleReviewEvaluation.compare(
          text: '哈哈',
          gold: [],
          before: [],
          after: labels,
        ),
        throwsFormatException,
      );
    },
  );
}
