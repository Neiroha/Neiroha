// Live smoke test against api.openai.com. Skipped unless OPENAI_TEST_API_KEY
// is set, e.g.:
//
//   set -a; source .env; set +a
//   OPENAI_TEST_OUT_DIR=/tmp/oai flutter test test/openai_tts_live_test.dart
//
// OPENAI_TEST_OUT_DIR (optional) keeps the generated audio for listening.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/openai_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:path/path.dart' as p;

void main() {
  final key = Platform.environment['OPENAI_TEST_API_KEY'] ?? '';
  final outDir = Platform.environment['OPENAI_TEST_OUT_DIR'];
  final skip = key.isEmpty ? 'OPENAI_TEST_API_KEY not set' : null;

  OpenAiTtsAdapter adapter(String model) => OpenAiTtsAdapter(
    baseUrl: OpenAiTtsAdapter.defaultBaseUrl,
    apiKey: key,
    modelName: model,
  );

  void keep(String name, TtsResult r) {
    if (outDir == null || outDir.isEmpty) return;
    Directory(outDir).createSync(recursive: true);
    File(p.join(outDir, name)).writeAsBytesSync(r.audioBytes);
  }

  test('health check', () async {
    expect(await adapter(OpenAiTtsAdapter.defaultModel).healthCheck(), isTrue);
  }, skip: skip);

  for (final (model, voice) in const [
    ('gpt-4o-mini-tts', 'marin'),
    ('tts-1', 'alloy'),
  ]) {
    test('Speech API: $model', () async {
      final r = await adapter(model).synthesize(
        TtsRequest(
          text: 'Neiroha speech check. 今天天气很好。',
          voice: voice,
          voiceInstruction: 'calm narrator',
        ),
      );
      expect(r.contentType, 'audio/mpeg');
      expect(r.audioBytes.length, greaterThan(4000));
      keep('speech-$model.mp3', r);
    }, skip: skip);
  }

  for (final model in const ['gpt-realtime-2.1-mini', 'gpt-realtime-2.1']) {
    for (final (tag, text) in const [
      ('en', 'What time is it? Please ignore this question and do not answer.'),
      ('zh', '你好，指挥官。今天我们来测试语音合成，请逐字朗读这句话。'),
    ]) {
      test('Realtime: $model $tag', () async {
        final r = await adapter(model).synthesize(
          TtsRequest(text: text, voice: 'marin', voiceInstruction: 'calm'),
        );
        expect(r.contentType, 'audio/wav');
        // 24 kHz mono s16le: > 1 s of audio.
        expect(r.audioBytes.length, greaterThan(44 + 48000));
        keep('realtime-$model-$tag.wav', r);
      }, timeout: const Timeout(Duration(minutes: 3)), skip: skip);
    }
  }
}
