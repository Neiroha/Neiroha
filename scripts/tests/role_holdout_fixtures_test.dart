import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';

void main() {
  final files = Directory('scripts/tests/fixtures/role_holdout')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  test(
    'fresh holdout cases cover chat, nested narration and listener reactions',
    () => expect(files, hasLength(3)),
  );
  for (final file in files) {
    test(
      '${file.uri.pathSegments.last}: exact source and unambiguous gold spans',
      () {
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final text = fixture['text'] as String;
        final parts = splitNovelText(text);
        expect(parts.map((s) => s.text).join(), text);
        for (final label in fixture['gold'] as List) {
          final snippet = label['match'] as String;
          final at = text.indexOf(snippet);
          expect(at, greaterThanOrEqualTo(0));
          expect(text.indexOf(snippet, at + 1), -1);
        }
      },
    );
  }
}
