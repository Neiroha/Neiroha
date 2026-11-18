import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';

void main() {
  test('retains exact CRLF, spacing and surrogate boundaries', () {
    const text = ' 𠮷野🌸站起。\r\n\r\n“你好。”\n“再见。”  ';
    final parts = NovelSemanticSegmenter.split(text);
    expect(parts.map((p) => p.text).join(), text);
    for (final p in parts) {
      expect(text.substring(p.start, p.end), p.text);
      expect(p.text.runes.any((r) => r >= 0xD800 && r <= 0xDFFF), isFalse);
    }
    expect(parts.where((p) => p.type == 'dialogue'), hasLength(2));
  });
  test('nested quoted speakers remain distinct semantic units', () {
    const text = '林舟说：“老人说过「别怕」，我记得。”王二答：“好。”';
    final parts = NovelSemanticSegmenter.split(text);
    expect(parts.map((p) => p.text).join(), text);
    expect(parts.where((p) => p.quoteDepth == 2).single.text, '「别怕」');
    expect(
      parts.where((p) => p.text.contains('老人') && p.text.contains('好。')),
      isEmpty,
    );
  });
  test('adjacent chat messages retain distinct senders and channels', () {
    const text = '【林舟：我来了[笑]。】【王二：等我。】\n【系统消息：王二加入群聊】';
    final parts = NovelSemanticSegmenter.split(text);
    expect(parts.map((p) => p.text).join(), text);
    expect(parts.map((p) => p.senderHint), ['林舟', '王二', '系统消息']);
    expect(parts.map((p) => p.channel), ['chat', 'chat', 'system']);
  });
  test('semantic utterances are independent of TTS length limits', () {
    final text = '“${List.filled(100, '不要把同一台词按字数切开，').join()}”';
    expect(NovelSemanticSegmenter.split(text), hasLength(1));
  });
  test('custom dialogue regex cannot cut a surrogate pair', () {
    // A custom regexp matching one UTF-16 unit must not turn emoji into broken pieces.
    const text = '🌸好';
    final parts = NovelSemanticSegmenter.split(
      text,
      extraDialogueRules: [RegExp(r'.')],
    );
    expect(parts.map((p) => p.text).join(), text);
    expect(
      parts.any((p) => p.text.runes.any((r) => r >= 0xD800 && r <= 0xDFFF)),
      isFalse,
    );
  });
}
