import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/storage/novel_dialogue_rules_service.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';

void main() {
  test('splitNovelText preserves quoted dialogue and punctuation', () {
    const source = '一。\n“好险好险，差点就成落汤鸡了……”\n即便是跑着进了宾馆的房间。';

    final segments = splitNovelText(source);
    final reconstructed = segments.map((segment) => segment.text).join('');

    expect(_compact(reconstructed), _compact(source));
    expect(
      segments.any(
        (segment) =>
            segment.type == 'dialogue' && segment.text == '“好险好险，差点就成落汤鸡了……”',
      ),
      isTrue,
    );
    expect(segments.first.text, '一。');
  });

  test('splitNovelText marks English double quotes as dialogue', () {
    const source = '她小声说："hello, commander." 然后笑了。';

    final segments = splitNovelText(source);

    expect(
      segments.any(
        (segment) =>
            segment.type == 'dialogue' && segment.text == '"hello, commander."',
      ),
      isTrue,
    );
    expect(
      _compact(segments.map((segment) => segment.text).join('')),
      _compact(source),
    );
  });

  test('punctuation-only quoted fragments can be skipped by playback', () {
    expect(isNovelPunctuationOnly('"……"'), isTrue);
    expect(isNovelPunctuationOnly('“……”'), isTrue);
    expect(isNovelPunctuationOnly('“唯我独尊”'), isFalse);
  });

  test('custom dialogue rules can classify book title brackets', () {
    const source = '她念出《密语》之后沉默。';
    final segments = splitNovelText(
      source,
      dialogueRules: const [
        NovelDialogueRule(
          id: 'custom.book',
          name: 'Book title',
          pattern: r'《[\s\S]*?》',
        ),
      ],
    );

    expect(
      segments.any(
        (segment) => segment.type == 'dialogue' && segment.text == '《密语》',
      ),
      isTrue,
    );
  });
}

String _compact(String value) => value.replaceAll(RegExp(r'\s+'), '');
