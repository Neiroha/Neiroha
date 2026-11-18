import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';
import 'support/role_eval_fixture.dart';

void main() {
  for (final file in Directory(
    'scripts/tests/fixtures/role_followup',
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
    test(
      '${file.uri.pathSegments.last} preserves all chapter text and unique score anchors',
      () {
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final text = fixture['text'] as String;
        final chapters = evaluationChapters(fixture);
        expect(
          chapters
              .expand(NovelSemanticSegmenter.split)
              .map((p) => p.text)
              .join(),
          text,
        );
        for (final label in fixture['gold'] as List) {
          final match = label['match'] as String;
          expect(text.split(match), hasLength(2), reason: match);
        }
        expect(
          evaluateIdentityChecks(fixture: fixture, labels: []),
          everyElement(containsPair('passed', false)),
        );
      },
    );
  }

  test(
    'same and distinct compare assigned IDs, while unassigned requires actual dialogue coverage',
    () {
      final fixture = <String, dynamic>{
        'text': '甲乙丙丁戊',
        'chapters': ['甲', '乙丙丁戊'],
        'identityChecks': [
          {
            'kind': 'same',
            'matches': ['甲', '乙'],
          },
          {
            'kind': 'distinct',
            'matches': ['乙', '丙'],
          },
          {
            'kind': 'same',
            'matches': ['丁', '戊'],
          },
          {
            'kind': 'unassigned',
            'matches': ['丁'],
          },
          {
            'kind': 'unassigned',
            'matches': ['戊'],
          },
        ],
      };
      final ids = ['a', 'a', 'b', null, null];
      final results = evaluateIdentityChecks(
        fixture: fixture,
        labels: [
          for (final (i, id) in ids.indexed)
            {
              'start': i,
              'end': i + 1,
              'characterId': id,
              'kind': i == 4 ? 'narrator' : 'dialogue',
            },
        ],
      );
      expect(results.map((r) => r['passed']), [true, true, false, true, false]);
      expect(results.map((r) => r['crossChapter']), [
        true,
        false,
        false,
        false,
        false,
      ]);
    },
  );
}
