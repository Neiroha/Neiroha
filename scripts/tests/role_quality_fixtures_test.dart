import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';

void main() {
  for (final file in Directory(
    'scripts/tests/fixtures/role_quality',
  ).listSync().whereType<File>()) {
    test(
      'quality fixture is independently scoreable: ${file.uri.pathSegments.last}',
      () {
        final fixture = jsonDecode(file.readAsStringSync()) as Map;
        final text = fixture['text'] as String;
        final roster = (fixture['roster'] as List)
            .map((r) => r['name'])
            .toSet();
        final pieces = NovelSemanticSegmenter.split(text);
        expect(pieces.map((s) => s.text).join(), text);
        expect(pieces.last.end, text.length);
        for (final gold in fixture['gold'] as List) {
          final match = gold['match'] as String;
          expect(match, isNotEmpty);
          expect(text.split(match), hasLength(2));
          expect([
            'narrator',
            'dialogue',
            'thought',
            'system',
          ], contains(gold['category']));
          if (gold['speaker'] != null) {
            expect(roster, contains(gold['speaker']));
          }
        }
        if (fixture['id'] == 'quality_long_station') {
          expect(pieces.length, greaterThan(100));
        }
      },
    );
  }
}
