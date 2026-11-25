// Live measure of the chain's ASR back-check: real TTS reads each line in
// full and with one clause left out, real STT transcribes it, and
// compareSpeech must flag the omission without flagging the full reads.
// Skipped unless OPENAI_KEY is set (GEMINI_KEY adds a second transcriber):
//
//   set -a; source .env; set +a
//   flutter test scripts/tests/speech_check_live_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/synthesis/speech_check.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

/// (language, full line, clause the omitted read leaves out).
const _lines = [
  ('zh', '今天下午三点，我们在图书馆门口集合，然后一起去博物馆参观。', '然后一起去博物馆参观'),
  ('zh', '她把信放进抽屉里，转身关上了窗户，屋里顿时安静下来。', '转身关上了窗户'),
  ('zh', '如果明天不下雨，我们就去山上看日出，顺便带上相机。', '顺便带上相机'),
  (
    'en',
    'We will meet at the library at three, and then walk to the museum together.',
    'and then walk to the museum together',
  ),
  (
    'en',
    'She put the letter in the drawer, closed the window, and the room went quiet.',
    'closed the window',
  ),
  (
    'en',
    'If it does not rain tomorrow, we will watch the sunrise from the hill with a camera.',
    'with a camera',
  ),
  ('ja', '明日の朝九時に駅の前で待ち合わせて、それから一緒に美術館へ行きましょう。', 'それから一緒に美術館へ行きましょう'),
  ('ja', '彼女は手紙を引き出しにしまって、窓を閉めると、部屋は静かになった。', '窓を閉めると'),
  ('ja', '雨が降らなければ、山の上から日の出を見て、写真もたくさん撮りたいです。', '写真もたくさん撮りたいです'),
];

const _timeout = Timeout(Duration(minutes: 10));

/// Whether [check] flags at least half of [omitted]'s units as missing.
bool _caught(SpeechCheck check, String omitted) {
  final want = [for (final u in speechUnits(omitted)) u.text];
  final flagged = [
    for (final run in check.missing)
      for (final u in speechUnits(run)) u.text,
  ];
  final pool = [...flagged];
  var hit = 0;
  for (final w in want) {
    if (pool.remove(w)) hit++;
  }
  return hit * 2 >= want.length;
}

void main() {
  final env = Platform.environment;
  final openAiKey = env['OPENAI_TEST_API_KEY'] ?? env['OPENAI_KEY'] ?? '';
  final geminiKey = env['GEMINI_API_KEY'] ?? env['GEMINI_KEY'] ?? '';
  final skip = openAiKey.isEmpty ? 'OPENAI_KEY not set' : null;
  final openai = const OpenAiPlugin().connect(
    ConnectionConfig(id: 'live', baseUrl: '', apiKey: openAiKey),
  );
  final transcribers = <String, ProviderConnection>{
    'openai': openai,
    if (geminiKey.isNotEmpty)
      'gemini': connectionForProvider(
        db.TtsProvider(
          id: 'gemini',
          name: 'Gemini',
          adapterType: AdapterType.geminiTts.name,
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: geminiKey,
          defaultModelName: AdapterType.geminiTts.defaultModel,
          enabled: true,
          position: 0,
          maxConcurrency: 1,
        ),
      ),
  };

  Future<Uint8List> speak(String text) async {
    final pcm = BytesBuilder(copy: false);
    await for (final e
        in openai
            .speechModel('gpt-realtime-2.1-mini')!
            .synthesize(
              TtsRequest(text: text, voice: 'marin', responseFormat: 'pcm'),
              cancellation: TtsCancelToken(),
            )) {
      if (e is TtsAudioChunk) pcm.add(e.bytes);
    }
    return wrapPcmAsWav(pcm.takeBytes(), sampleRate: 24000);
  }

  test(
    'back-check flags omissions in zh / en / ja',
    () async {
      // name → language → (caught, omitted reads, false alarms, full reads)
      final tally = <String, Map<String, List<int>>>{};
      for (final (lang, full, omitted) in _lines) {
        final shortened = full.replaceFirst(omitted, '');
        final audio = {
          'full': await speak(full),
          'omitted': await speak(shortened),
        };
        for (final MapEntry(key: name, value: c) in transcribers.entries) {
          final row = tally
              .putIfAbsent(name, () => {})
              .putIfAbsent(lang, () => [0, 0, 0, 0]);
          for (final MapEntry(key: kind, value: wav) in audio.entries) {
            final heard = await c.transcriber()!.transcribe(
              AudioInput(wav),
              options: TranscribeOptions(languages: [lang]),
            );
            final check = compareSpeech(full, heard.text);
            // ignore: avoid_print
            print(
              '[$name/$lang/$kind] score ${check.score.toStringAsFixed(2)} '
              'missing ${check.missing} ← ${heard.text}',
            );
            if (kind == 'omitted') {
              row[1]++;
              if (_caught(check, omitted)) row[0]++;
            } else {
              row[3]++;
              if (!check.clean) row[2]++;
            }
          }
        }
      }
      for (final MapEntry(key: name, value: langs) in tally.entries) {
        for (final MapEntry(key: lang, value: r) in langs.entries) {
          // ignore: avoid_print
          print(
            'SUMMARY $name $lang: caught ${r[0]}/${r[1]}, '
            'false alarms ${r[2]}/${r[3]}',
          );
          expect(r[0], r[1], reason: '$name $lang missed an omission');
        }
      }
    },
    skip: skip,
    timeout: _timeout,
  );
}
