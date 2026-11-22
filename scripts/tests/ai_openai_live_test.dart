// Live smoke test of every OpenAI capability through the new AI layer.
// Skipped unless OPENAI_TEST_API_KEY (or OPENAI_KEY from .env) is set:
//
//   set -a; source .env; set +a
//   OPENAI_TEST_OUT_DIR=/tmp/oai flutter test scripts/tests/ai_openai_live_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/capability_health.dart';
import 'package:neiroha/data/ai/core/connection_config.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/providers/openai/openai_plugin.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';
import 'package:path/path.dart' as p;

const _sentence = 'The quick brown fox jumps over the lazy dog near the river.';
const _timeout = Timeout(Duration(minutes: 3));

void main() {
  final env = Platform.environment;
  final key = env['OPENAI_TEST_API_KEY'] ?? env['OPENAI_KEY'] ?? '';
  final outDir = env['OPENAI_TEST_OUT_DIR'];
  final skip = key.isEmpty ? 'OPENAI_TEST_API_KEY / OPENAI_KEY not set' : null;
  final openai = const OpenAiPlugin().connect(
    ConnectionConfig(id: 'live', baseUrl: '', apiKey: key),
  );
  Uint8List? speechPcm; // 24 kHz mono PCM16 of [_sentence]

  void keep(String name, List<int> bytes) {
    if (outDir == null || outDir.isEmpty) return;
    Directory(outDir).createSync(recursive: true);
    File(p.join(outDir, name)).writeAsBytesSync(bytes);
  }

  Future<Uint8List> synthesize(String model, String voice) async {
    final pcm = BytesBuilder(copy: false);
    TtsAudioFormat? format;
    await for (final e
        in openai
            .speechModel(model)!
            .synthesize(
              TtsRequest(text: _sentence, voice: voice, responseFormat: 'pcm'),
              cancellation: TtsCancelToken(),
            )) {
      if (e is TtsAudioStarted) format = e.format;
      if (e is TtsAudioChunk) pcm.add(e.bytes);
    }
    expect(format?.encoding, AudioEncoding.pcmS16le);
    expect(format?.sampleRate, 24000);
    return pcm.takeBytes();
  }

  Future<Uint8List> pcm() async =>
      speechPcm ??= await synthesize('gpt-realtime-2.1-mini', 'marin');

  /// Streams [audio] in 200 ms chunks followed by [silenceMs] of silence.
  void stream(
    AudioStreamSession session,
    Uint8List audio, {
    int silenceMs = 0,
  }) {
    const chunk = 9600;
    final all = Uint8List.fromList([
      ...audio,
      ...Uint8List(24000 * 2 * silenceMs ~/ 1000),
    ]);
    for (var i = 0; i < all.length; i += chunk) {
      session.sendPcm(
        Uint8List.sublistView(
          all,
          i,
          i + chunk > all.length ? all.length : i + chunk,
        ),
      );
    }
  }

  test(
    'health: one key serves every capability',
    () async {
      final health = await openai.check();
      for (final entry in health.entries) {
        // ignore: avoid_print
        print('  ${entry.key.name}: ${entry.value}');
      }
      for (final cap in openai.capabilities) {
        expect(health[cap]!.state, HealthState.ok, reason: cap.name);
        expect(health[cap]!.models, contains(openai.defaultModel(cap)!.id));
      }
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'llm: default model answers via Responses',
    () async {
      final llm = openai.languageModel()!;
      final text = await llm.complete(const [
        LlmChatMessage(
          role: 'user',
          content: 'Reply with exactly the word: pong',
        ),
      ], maxOutputTokens: 512);
      // ignore: avoid_print
      print('  ${llm.descriptor.id}: $text');
      expect(text.toLowerCase(), contains('pong'));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'llm: structured output',
    () async {
      final result = await openai.languageModel()!.structured(
        const [
          LlmChatMessage(
            role: 'user',
            content: 'Who speaks in: "Run!" shouted Alice. Answer as JSON.',
          ),
        ],
        schemaName: 'speaker',
        schema: const {
          'type': 'object',
          'properties': {
            'speaker': {'type': 'string'},
          },
          'required': ['speaker'],
          'additionalProperties': false,
        },
        maxOutputTokens: 1024,
      );
      expect('${result.object['speaker']}'.toLowerCase(), contains('alice'));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'tts: Realtime model streams 24 kHz PCM',
    () async {
      final audio = await pcm();
      expect(audio.length, greaterThan(24000)); // > 0.5 s
      keep('tts-realtime.wav', wrapPcmAsWav(audio, sampleRate: 24000));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'tts: Speech API model (until 2027-01-06)',
    () async {
      final audio = await synthesize('gpt-4o-mini-tts', 'coral');
      expect(audio.length, greaterThan(24000));
      keep('tts-speech.wav', wrapPcmAsWav(audio, sampleRate: 24000));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'vad: on-device VAD finds speech in the TTS output',
    () async {
      final segments = OnDevicePlugin.builtIn().vad()!.segments(
        await pcm(),
        sampleRate: 24000,
      );
      // ignore: avoid_print
      print('  segments: $segments');
      expect(segments, isNotEmpty);
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'stt: gpt-transcribe file transcription',
    () async {
      final wav = wrapPcmAsWav(await pcm(), sampleRate: 24000);
      final transcript = await openai.transcriber()!.transcribe(
        AudioInput(wav),
        options: const TranscribeOptions(keywords: ['fox']),
      );
      // ignore: avoid_print
      print('  ${transcript.text} ${transcript.languages}');
      expect(transcript.text.toLowerCase(), contains('fox'));
    },
    skip: skip,
    timeout: _timeout,
  );

  for (final model in const ['gpt-live-transcribe', 'gpt-realtime-whisper']) {
    test(
      'stt: $model streaming transcription',
      () async {
        final session = await openai.streamingTranscriber(model)!.open();
        final finals = <String>[];
        final sub = session.events.listen((e) {
          if (e is TranscriptFinal) finals.add(e.text);
        }, onError: (_) {});
        stream(session, await pcm(), silenceMs: 300);
        await session.finish(timeout: const Duration(minutes: 1));
        await sub.cancel();
        // ignore: avoid_print
        print('  $model: $finals');
        expect(finals.join(' ').toLowerCase(), contains('fox'));
      },
      skip: skip,
      timeout: _timeout,
    );
  }

  test(
    'realtime: text turn returns spoken audio',
    () async {
      final session = await openai.realtimeModel()!.connect(
        const RealtimeConfig(
          instructions: 'Answer in one short English sentence.',
          voice: 'marin',
        ),
      );
      var audioBytes = 0;
      final sub = session.events.listen((e) {
        if (e is AudioDelta) audioBytes += e.pcm.length;
      }, onError: (_) {});
      session.sendText('Say hello to the commander.');
      final done = await session.respond(timeout: const Duration(minutes: 1));
      await sub.cancel();
      await session.close();
      // ignore: avoid_print
      print('  reply: ${done.text} ($audioBytes bytes)');
      expect(audioBytes, greaterThan(24000));
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'realtime: spoken turn with input transcription',
    () async {
      final session = await openai.realtimeModel()!.connect(
        const RealtimeConfig(
          instructions: 'Repeat what the user said, in English.',
          transcribeInput: true,
        ),
      );
      final heard = <String>[];
      final sub = session.events.listen((e) {
        if (e is TranscriptFinal) heard.add(e.text);
      }, onError: (_) {});
      stream(session, await pcm());
      await session.finish(timeout: const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(seconds: 2));
      await sub.cancel();
      await session.close();
      // ignore: avoid_print
      print('  heard: $heard');
    },
    skip: skip,
    timeout: _timeout,
  );

  test(
    'translate: English speech to Spanish',
    () async {
      final session = await openai.translator()!.open(targetLanguage: 'es');
      final source = StringBuffer();
      final target = StringBuffer();
      final audio = BytesBuilder(copy: false);
      final sub = session.events.listen((e) {
        if (e is TranscriptDelta) (e.source ? source : target).write(e.text);
        if (e is AudioDelta) audio.add(e.pcm);
      }, onError: (_) {});
      stream(session, await pcm(), silenceMs: 1500);
      await session.finish(timeout: const Duration(minutes: 1));
      await sub.cancel();
      final translated = audio.takeBytes();
      keep('translate-es.wav', wrapPcmAsWav(translated, sampleRate: 24000));
      // ignore: avoid_print
      print(
        '  source: $source\n  target: $target (${translated.length} bytes)',
      );
      expect(target.toString().trim(), isNotEmpty);
      expect(translated.length, greaterThan(24000));
    },
    skip: skip,
    timeout: _timeout,
  );

  test('capability gaps are explicit', () {
    expect(openai.capabilities, isNot(contains(AiCapability.vc)));
    expect(openai.voiceConverter(), isNull);
  });
}
