// Silence trim and ASR read-back steps of a character's processing chain.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/data/services/synthesis/speech_check_log.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/speech_check.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

const _rate = 16000;

/// [ms] of PCM16 mono: a 440 Hz-ish square tone, or silence.
Uint8List _pcm(int ms, {bool loud = true}) {
  final n = _rate * ms ~/ 1000;
  final data = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    data.setInt16(
      i * 2,
      loud ? ((i ~/ 18).isEven ? 8000 : -8000) : 0,
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}

Uint8List _cat(List<Uint8List> parts) {
  final b = BytesBuilder();
  parts.forEach(b.add);
  return b.takeBytes();
}

int _ms(Uint8List pcm) => pcm.length * 1000 ~/ (_rate * 2);

class _Stt implements Transcriber {
  _Stt(this.reply);
  final String Function(AudioInput audio) reply;
  final heard = <AudioInput>[];
  @override
  ModelDescriptor get descriptor => const ModelDescriptor(
    id: 'stt',
    capability: AiCapability.stt,
    protocol: AiProtocol.native,
  );
  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) async {
    heard.add(audio);
    return Transcript(reply(audio));
  }
}

void main() {
  group('compareSpeech', () {
    test('a clean read scores 1 with nothing missing', () {
      final c = compareSpeech('今天天气很好。', '今天天气很好');
      expect(c.score, 1);
      expect(c.clean, isTrue);
    });

    test('lists skipped CJK runs and English words', () {
      final zh = compareSpeech('今天天气很好，我们出去走走吧。', '今天天气很好，走走吧');
      expect(zh.missing, ['我们出去']);
      expect(zh.score, closeTo(9 / 13, 1e-9));
      final en = compareSpeech(
        'The quick brown fox jumps over the lazy dog.',
        'the quick fox jumps over the dog',
      );
      expect(en.missing, ['brown', 'lazy']);
    });

    test('ignores punctuation, case and extra heard words', () {
      final c = compareSpeech('Hello, World!', 'uh hello there world');
      expect(c.clean, isTrue);
    });

    test('nothing heard misses the whole line', () {
      final c = compareSpeech('Good night', '');
      expect(c.score, 0);
      expect(c.missing, ['good night']);
    });

    // Seen with real STT (speech_check_live_test): numbers come back as
    // digits and 她 / 他 sound the same.
    test('numbers match across scripts; homophones are not misses', () {
      expect(compareSpeech('明日の朝九時に', '明日の朝9時に').clean, isTrue);
      expect(compareSpeech('二十五个人，一百零三页', '25个人，103页').clean, isTrue);
      expect(compareSpeech('We meet at three.', 'We meet at 3.').clean, isTrue);
      expect(compareSpeech('她把信放进抽屉', '他把信放进抽屉').clean, isTrue);
      expect(compareSpeech('我们一起走', '我们一起走').clean, isTrue);
      final kana = compareSpeech('手紙を引き出しにしまって', '手紙をひきだしにしまって');
      expect(kana.clean, isTrue);
      expect(kana.score, 1);
      // A kanji word left out is still a miss.
      expect(compareSpeech('窓を閉めると静か', '静か').missing, ['窓を閉めると']);
    });

    test('long runs the text lacks are reported as extra', () {
      final c = compareSpeech(
        'We will meet at the library.',
        'All right, let me read that aloud. We will meet at the library.',
      );
      expect(c.missing, isEmpty);
      expect(c.extra, ['all right let me read that aloud']);
      expect(c.clean, isFalse);
      expect(
        compareSpeech('Hello world', 'uh hello there world').clean,
        isTrue,
      );
    });
  });

  group('SilenceTrimStage', () {
    const trim = SilenceTrimStage();

    test('cuts edges to 60 ms and long pauses to 350 ms', () {
      final pcm = _cat([
        _pcm(500, loud: false),
        _pcm(300),
        _pcm(1000, loud: false),
        _pcm(300),
        _pcm(400, loud: false),
      ]);
      final out = trim.apply(pcm, _rate, 1);
      expect(_ms(out), 60 + 300 + 350 + 300 + 60);
    });

    test('keeps short pauses and silent clips as they are', () {
      final pcm = _cat([_pcm(200), _pcm(200, loud: false), _pcm(200)]);
      expect(_ms(trim.apply(pcm, _rate, 1)), 600);
      final silent = _pcm(400, loud: false);
      expect(trim.apply(silent, _rate, 1), same(silent));
    });
  });

  group('pipeline audio steps', () {
    Stream<TtsEvent> speak(String _, TtsCancelToken _) => Stream.fromIterable([
      const TtsAudioStarted(
        TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: _rate, channels: 1),
      ),
      TtsAudioChunk(
        _cat([_pcm(400, loud: false), _pcm(500), _pcm(400, loud: false)]),
      ),
      const TtsSynthesisCompleted(),
    ]);

    test('trim shortens each sentence and the check hears it', () async {
      final checks = <SpeechCheck>[];
      final stt = _Stt((_) => '你好');
      final pipeline = SentenceSpeechPipeline(
        speak: speak,
        conversions: [
          const SilenceTrimStage(),
          SpeechCheckStage(stt, report: checks.add),
        ],
      );
      final events = await pipeline
          .run(
            Stream.fromIterable(['你好。', '再见。']),
            cancellation: TtsCancelToken(),
          )
          .toList();
      final pcm = _cat([
        for (final e in events)
          if (e is TtsAudioChunk) e.bytes,
      ]);
      expect(_ms(pcm), 2 * (60 + 500 + 60));
      await pumpEventQueue();
      expect(checks.map((c) => c.expected), ['你好。', '再见。']);
      expect(checks.first.clean, isTrue);
      expect(checks.last.missing, ['再见']);
      // The check hears the trimmed clip as WAV.
      expect(stt.heard.first.contentType, 'audio/wav');
    });

    test('an STT failure is reported, not thrown', () async {
      final checks = <SpeechCheck>[];
      final stt = _Stt((_) => throw StateError('offline'));
      final events = await SentenceSpeechPipeline(
        speak: speak,
        conversions: [SpeechCheckStage(stt, report: checks.add)],
      ).run(Stream.value('Hi.'), cancellation: TtsCancelToken()).toList();
      expect(events.last, isA<TtsSynthesisCompleted>());
      await pumpEventQueue();
      expect(checks.single.error, isA<StateError>());
      expect(checks.single.clean, isFalse);
    });
  });

  test('trim and verify steps are ready without a model and round-trip', () {
    final chain = VoiceChain([
      const VoiceChainStep(
        kind: VoiceChainStepKind.verify,
        targetLanguage: 'zh',
      ),
      const VoiceChainStep(kind: VoiceChainStepKind.translate),
      const VoiceChainStep(kind: VoiceChainStepKind.trim),
    ]);
    expect(chain.audioSteps.map((s) => s.kind), [
      VoiceChainStepKind.verify,
      VoiceChainStepKind.trim,
    ]);
    final back = VoiceChain.fromJson(chain.toJson());
    expect(back.steps.first.targetLanguage, 'zh');
    expect(back.signature, chain.signature);
    expect(canConvertPerSentence([const SilenceTrimStage()], null), isTrue);
  });

  test('the check log keeps the latest results per character', () async {
    final log = SpeechCheckLog.instance;
    final seen = <int>[];
    final sub = log.watch('a1').listen((l) => seen.add(l.length));
    for (var i = 0; i < SpeechCheckLog.keep + 2; i++) {
      log.add(compareSpeech('x', 'x').forAsset('a1'));
    }
    log.add(compareSpeech('y', 'y').forAsset('other'));
    await pumpEventQueue();
    expect(log.recent('a1'), hasLength(SpeechCheckLog.keep));
    expect(seen.last, SpeechCheckLog.keep);
    await sub.cancel();
  });
}
