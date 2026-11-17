import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_analysis_context.dart';
import 'package:neiroha/data/services/novel/role_doubt_detector.dart';
import 'package:neiroha/domain/novel/role_models.dart';

const roles = NovelRoleSnapshot(
  characters: [
    StoryCharacter(id: 'lin', projectId: 'book', name: '林舟'),
    StoryCharacter(id: 'wang', projectId: 'book', name: '王二'),
  ],
);
db.NovelSegment row(String id, String text, {int index = 0}) => db.NovelSegment(
  id: id,
  projectId: 'book',
  chapterId: 'chapter',
  globalIndex: index,
  orderIndex: index,
  segmentText: text,
  segmentType: 'dialogue',
  missing: false,
);
SegmentAnnotation label(db.NovelSegment s, String person) => SegmentAnnotation(
  segmentId: s.id,
  projectId: s.projectId,
  textRevision: novelTextRevision(s.segmentText),
  characterId: person,
  kind: NovelSegmentKind.dialogue,
  reviewState: NovelReviewState.inferred,
);

void main() {
  test(
    'an inferred message sender mismatch is flagged without replacing identity',
    () {
      final s = row('message', '【林舟：大家好。】');
      final labels = [label(s, 'wang')];
      final doubts = RoleDoubtDetector.inspect(
        labels: labels,
        roles: roles,
        context: RoleAnalysisContext([s]),
      );
      expect(doubts.map((d) => d.code), contains('message_sender'));
      final flagged = RoleDoubtDetector.flag(labels, doubts).single;
      expect(flagged.characterId, 'wang');
      expect(flagged.reviewState, NovelReviewState.conflict);
    },
  );
  test(
    'legacy mixed rows need splitting rather than a confident single voice',
    () {
      for (final text in ['【林舟：好。】【王二：不。】', '“好。”“不。”', '她笑了。“好。”']) {
        final s = row('mixed', text);
        final doubts = RoleDoubtDetector.inspect(
          labels: [label(s, 'lin')],
          roles: roles,
          context: RoleAnalysisContext([s]),
        );
        expect(doubts.map((d) => d.code), contains('mixed_turn'), reason: text);
      }
    },
  );
  test('explicit attribution distinguishes the speaker from the addressee', () {
    final cue = row('cue', '林舟对王二说：');
    final s = row('line', '“你先走。”', index: 1);
    final doubts = RoleDoubtDetector.inspect(
      labels: [label(s, 'wang')],
      roles: roles,
      context: RoleAnalysisContext([cue, s]),
    );
    expect(doubts.map((d) => d.code), contains('attribution'));
  });
  test('listener reactions alone do not establish speech attribution', () {
    final before = row('before', '王二点点头。');
    final s = row('line', '“你先走。”', index: 1);
    final after = row('after', '林舟笑了。', index: 2);
    final doubts = RoleDoubtDetector.inspect(
      labels: [label(s, 'wang')],
      roles: roles,
      context: RoleAnalysisContext([before, s, after]),
    );
    expect(doubts.where((d) => d.code == 'attribution'), isEmpty);
  });
  test('self-address and overlapping identities are independent doubts', () {
    final s = row('line', '“林舟，听我说。”');
    final duplicateRoles = NovelRoleSnapshot(
      characters: [
        ...roles.characters,
        const StoryCharacter(
          id: 'other',
          projectId: 'book',
          name: '小林',
          aliases: ['林舟'],
        ),
      ],
    );
    final doubts = RoleDoubtDetector.inspect(
      labels: [label(s, 'lin')],
      roles: duplicateRoles,
      context: RoleAnalysisContext([s]),
    );
    expect(
      doubts.map((d) => d.code),
      containsAll(['addressee', 'duplicate_identity']),
    );
  });
  test(
    'inferred spot checks do not force a conflict or manual confirmation',
    () {
      final s = row('audit', '“好。”', index: 16);
      final labels = [label(s, 'lin')];
      final doubts = RoleDoubtDetector.inspect(
        labels: labels,
        roles: roles,
        context: RoleAnalysisContext([s]),
      );
      expect(doubts.single.code, 'inferred_audit');
      expect(
        RoleDoubtDetector.flag(labels, doubts).single.reviewState,
        NovelReviewState.inferred,
      );
    },
  );
}
