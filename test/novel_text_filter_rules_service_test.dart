import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/storage/novel_text_filter_rules_service.dart';

void main() {
  test('built-in emoji filter removes emoji before synthesis', () {
    final filtered = NovelTextFilterRulesService.applyFilters(
      '厉害 ❤️ 好厉害啊 😂',
      NovelTextFilterRulesService.builtInRules,
    );

    expect(filtered, '厉害  好厉害啊 ');
  });

  test('custom regex filter can replace matched text', () {
    final filtered = NovelTextFilterRulesService.applyFilters('A[skip]B', [
      const NovelTextFilterRule(
        id: 'custom.brackets',
        name: 'brackets',
        pattern: r'\[.*?\]',
        replacement: ' ',
      ),
    ]);

    expect(filtered, 'A B');
  });
}
