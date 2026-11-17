import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';

void main() {
  final fixtures =
      Directory('scripts/tests/fixtures/role_assign')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  test(
    'twelve attributed evaluation fixtures are available',
    () => expect(fixtures, hasLength(12)),
  );
  for (final file in fixtures) {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    test(
      '${data['id']}: local segmentation preserves source and gold spans',
      () {
        final text = data['text'] as String;
        final segments = splitNovelText(text);
        String compact(String source) => source.replaceAll(RegExp(r'\s+'), '');
        expect(compact(segments.map((s) => s.text).join()), compact(text));
        for (final gold in data['gold'] as List) {
          expect(
            text.contains(gold['match'] as String),
            isTrue,
            reason: '${data['id']}: ${gold['match']}',
          );
        }
      },
    );
  }
}
