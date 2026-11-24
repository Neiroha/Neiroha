// End-to-end latency of a character chain: LLM translate (streamed) →
// self-hosted TTS → RVC, sentence by sentence, against the whole-line path.
// Runs only when the LLM key and every server answer:
//
//   set -a; source .env; set +a   # GEMINI_KEY, IRODORI_URL, GPT_SOVITS_URL, RVC_URL
//   TTS_TEST_OUT_DIR=/tmp/chain flutter test scripts/tests/streaming_chain_live_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/sentence_chunker.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:path/path.dart' as p;

const _line =
    'Welcome back, Commander. The fleet has returned safely. '
    'Tomorrow we sail at dawn, so please rest well tonight.';

db.TtsProvider _row(
  String id,
  String type,
  String url,
  String model, [
  String key = '',
]) => db.TtsProvider(
  id: id,
  name: id,
  adapterType: type,
  baseUrl: url,
  apiKey: key,
  defaultModelName: model,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

Future<bool> _up(String? url) async {
  if (url == null || url.isEmpty) return false;
  final root = url.replaceFirst(RegExp(r'/v1/?$'), '');
  try {
    final r = await Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 3)),
    ).get<Object>('$root/health');
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

class _Run {
  Duration? firstAudio;
  late Duration total;
  int rate = 0;
  final pcm = BytesBuilder();
}

Future<_Run> _measure(Stream<TtsEvent> events) async {
  final run = _Run();
  final clock = Stopwatch()..start();
  await for (final e in events) {
    if (e is TtsAudioStarted) run.rate = e.format.sampleRate ?? 0;
    if (e is TtsAudioChunk) {
      run.firstAudio ??= clock.elapsed;
      run.pcm.add(e.bytes);
    }
  }
  run.total = clock.elapsed;
  return run;
}

Future<void> main() async {
  final env = Platform.environment;
  final key = env['GEMINI_API_KEY'] ?? env['GEMINI_KEY'] ?? '';
  final irodori = env['IRODORI_URL'];
  final sovits = env['GPT_SOVITS_URL'];
  final rvc = env['RVC_URL'];
  final out = env['TTS_TEST_OUT_DIR'];
  final ready =
      key.isNotEmpty &&
      await _up(irodori) &&
      await _up(sovits) &&
      await _up(rvc);

  final rows = [
    if (key.isNotEmpty)
      _row(
        'gemini',
        'geminiTts',
        'https://generativelanguage.googleapis.com',
        'gemini-3.8-flash-tts',
        key,
      ),
    _row('irodori', 'irodori', irodori ?? '', 'azurlane'),
    _row('sovits', 'gptSovits', sovits ?? '', 'azurlane-voices-v5dev'),
    _row('rvc', 'rvc', rvc ?? '', 'auto'),
  ];
  const translate = VoiceChainStep(
    kind: VoiceChainStepKind.translate,
    connectionId: 'gemini',
    modelId: 'gemini-3.5-flash-lite',
    targetLanguage: 'Japanese',
  );
  const convert = VoiceChainStep(
    kind: VoiceChainStepKind.convert,
    connectionId: 'rvc',
    targetVoice: 'kikiV1',
  );

  for (final (name, provider, voice) in [
    ('Irodori', 'irodori', 'al-ship-30505-ja'),
    ('GPT-SoVITS', 'sovits', 'al-ship-30505-ja-v5dev'),
  ]) {
    test(
      '$name: LLM → TTS → RVC streams by sentence',
      () async {
        final router = CapabilityRouter.fromProviders(rows);
        final runner = VoiceChainRunner(router);
        final row = rows.firstWhere((r) => r.id == provider);
        const chain = VoiceChain([translate, convert]);
        final request = TtsRequest(
          text: _line,
          voice: voice,
          textLang: 'ja',
          responseFormat: 'pcm',
        );

        // New path: streamed LLM, per-sentence TTS and RVC.
        final chained = ChainedTtsAdapter(createAdapter(row), chain, runner);
        final streamed = await _measure(
          chained.synthesizeStream(request, cancellation: TtsCancelToken()),
        );

        // Old path: whole translation, whole TTS, whole conversion.
        final clock = Stopwatch()..start();
        final text = await runner.prepareText(_line, chain);
        final spoken = await createAdapter(
          row,
        ).synthesize(request.withText(text).asWholeFile());
        final whole = await runner.convertAudio(spoken, chain);
        final wholeTime = clock.elapsed;

        expect(streamed.pcm.length, greaterThan(48000));
        expect(parsePcmWav(whole.audioBytes).pcm, isNotEmpty);
        expect(streamed.firstAudio!, lessThan(wholeTime));
        // ignore: avoid_print
        print(
          '$name  streamed: first audio ${streamed.firstAudio!.inMilliseconds} ms, '
          'done ${streamed.total.inMilliseconds} ms  |  '
          'whole line: first audio ${wholeTime.inMilliseconds} ms',
        );
        if (out != null && out.isNotEmpty) {
          Directory(out).createSync(recursive: true);
          File(p.join(out, 'chain-$provider-streamed.wav')).writeAsBytesSync(
            wrapPcmAsWav(streamed.pcm.takeBytes(), sampleRate: streamed.rate),
          );
          File(
            p.join(out, 'chain-$provider-whole.wav'),
          ).writeAsBytesSync(whole.audioBytes);
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
      skip: ready ? null : 'LLM key or a self-hosted server is unavailable',
    );
  }

  test('stage timings: first delta, first sentence, TTS, RVC', () async {
    final router = CapabilityRouter.fromProviders(rows);
    final runner = VoiceChainRunner(router);
    final llm = runner.languageModel(translate);
    expect(llm, isA<StreamingLanguageModel>());
    final clock = Stopwatch()..start();
    Duration? firstDelta;
    Duration? firstSentence;
    var deltas = 0;
    String? sentence;
    await for (final s in chunkSentences(
      runner
          .streamText(
            _line,
            const VoiceChain([translate]),
            cancellation: TtsCancelToken(),
          )
          .map((d) {
            deltas++;
            firstDelta ??= clock.elapsed;
            return d;
          }),
    )) {
      if (sentence == null) {
        sentence = s;
        firstSentence = clock.elapsed;
      }
    }
    final llmDone = clock.elapsed;
    clock.reset();
    final tts = await createAdapter(
      rows.firstWhere((r) => r.id == 'irodori'),
    ).synthesize(TtsRequest(text: sentence!, voice: 'al-ship-30505-ja'));
    final ttsTime = clock.elapsed;
    clock.reset();
    final converted = await _measure(
      convertAsStream(
        runner.converter(convert),
        AudioInput(tts.audioBytes),
        targetVoice: 'kikiV1',
        cancellation: TtsCancelToken(),
      ),
    );
    // ignore: avoid_print
    print(
      'LLM: first delta ${firstDelta!.inMilliseconds} ms, first sentence '
      '${firstSentence!.inMilliseconds} ms ("$sentence"), done '
      '${llmDone.inMilliseconds} ms, $deltas deltas  |  Irodori sentence '
      '${ttsTime.inMilliseconds} ms  |  RVC first audio '
      '${converted.firstAudio!.inMilliseconds} ms',
    );
    expect(deltas, greaterThan(1));
  }, skip: ready ? null : 'LLM key or a self-hosted server is unavailable');
}
