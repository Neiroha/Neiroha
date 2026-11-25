import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/sentence_chunker.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

Uint8List _pcm(int samples, [int value = 100]) =>
    Int16List.fromList(List.filled(samples, value)).buffer.asUint8List();

/// Emits [text] one character at a time, like an LLM token stream.
Stream<String> _typed(String text) async* {
  for (final c in text.split('')) {
    await Future<void>.delayed(Duration.zero);
    yield c;
  }
}

const _d = ModelDescriptor(
  id: 'vc',
  capability: AiCapability.vc,
  protocol: AiProtocol.native,
);

class _Vc implements StreamingVoiceConverter {
  final inputs = <Uint8List>[];
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) => throw UnimplementedError();
  @override
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  }) async* {
    inputs.add(audio.bytes);
    final wav = parsePcmWav(audio.bytes);
    yield const TtsAudioStarted(
      TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 40000, channels: 1),
    );
    // Same length at 40 kHz, value marks "converted".
    final samples = wav.pcm.length ~/ 2 * 40000 ~/ wav.sampleRate;
    yield TtsAudioChunk(_pcm(samples ~/ 2, 7));
    yield TtsAudioChunk(_pcm(samples - samples ~/ 2, 7));
    yield const TtsSynthesisCompleted();
  }
}

void main() {
  group('SentenceChunker', () {
    test('splits Chinese, Japanese and English as sentences end', () {
      expect(splitSentences('指挥官，今天辛苦了。明天也一起努力吧！好吗？'), [
        '指挥官，今天辛苦了。',
        '明天也一起努力吧！',
        '好吗？',
      ]);
      expect(splitSentences('今日もお疲れさま。「はい」と言った。'), ['今日もお疲れさま。', '「はい」と言った。']);
      expect(splitSentences('Hello there. It costs 3.5 dollars. Bye now.'), [
        'Hello there.',
        'It costs 3.5 dollars.',
        'Bye now.',
      ]);
    });

    test('keeps closing quotes and stacked marks with the sentence', () {
      expect(splitSentences('「本当ですか！？」彼は言った。'), ['「本当ですか！？」', '彼は言った。']);
    });

    test('very short sentences join the next one', () {
      expect(splitSentences('嗯。我知道了。'), ['嗯。我知道了。']);
    });

    test(
      'streams: a sentence is released when it ends, not at the end',
      () async {
        final c = SentenceChunker();
        expect(c.add('指挥官，今天'), isEmpty);
        expect(c.add('辛苦了。明'), ['指挥官，今天辛苦了。']);
        expect(c.add('天见'), isEmpty);
        expect(c.flush(), '明天见');
      },
    );

    test('a long first sentence may break at a comma', () {
      final c = SentenceChunker(firstSoftBreak: 10);
      expect(c.add('这是一个很长很长的开头，后面还有'), ['这是一个很长很长的开头，']);
      // Later sentences wait for a real end.
      expect(c.add('很多很多内容，还是没有说完，继续'), isEmpty);
    });

    test('overlong text breaks at its last pause', () {
      final c = SentenceChunker(maxChars: 20, firstSoftBreak: 1000);
      final out = c.add('一二三四五六七八九十，一二三四五六七八九十一二三四五');
      expect(out.single, '一二三四五六七八九十，');
    });

    test('chunkSentences over a token stream', () async {
      expect(await chunkSentences(_typed('第一句。第二句！尾巴')).toList(), [
        '第一句。',
        '第二句！',
        '尾巴',
      ]);
    });
  });

  group('SentenceSpeechPipeline', () {
    test(
      'first sentence plays while later ones are still generating',
      () async {
        final started = <String>[];
        final gates = <String, Completer<void>>{};
        final pipeline = SentenceSpeechPipeline(
          speak: (s, _) async* {
            started.add(s);
            await (gates[s] ??= Completer<void>()).future;
            yield const TtsAudioStarted(
              TtsAudioFormat(
                AudioEncoding.pcmS16le,
                sampleRate: 24000,
                channels: 1,
              ),
            );
            yield TtsAudioChunk(_pcm(2400));
            yield const TtsSynthesisCompleted();
          },
        );
        final sentences = StreamController<String>();
        final events = <TtsEvent>[];
        final done = pipeline
            .run(sentences.stream, cancellation: TtsCancelToken())
            .listen(events.add)
            .asFuture<void>();
        sentences.add('one.');
        sentences.add('two.');
        sentences.add('three.');
        await pumpEventQueue();
        // One sentence in TTS at a time.
        expect(started, ['one.']);
        (gates['one.'] ??= Completer()).complete();
        await pumpEventQueue();
        expect(events.whereType<TtsAudioChunk>(), hasLength(1));
        // "two" speaks while "one" plays; "three" waits for a lookahead slot.
        expect(started, ['one.', 'two.']);
        (gates['two.'] ??= Completer()).complete();
        await pumpEventQueue();
        expect(started, ['one.', 'two.', 'three.']);
        (gates['three.'] ??= Completer()).complete();
        await sentences.close();
        await done;
        expect(events.first, isA<TtsAudioStarted>());
        expect(events.whereType<TtsAudioChunk>(), hasLength(3));
        expect(events.last, isA<TtsSynthesisCompleted>());
      },
    );

    test('WAV sentences become one PCM stream; rates are unified', () async {
      var n = 0;
      final pipeline = SentenceSpeechPipeline(
        speak: (s, _) async* {
          final rate = n++ == 0 ? 48000 : 24000;
          final wav = wrapPcmAsWav(_pcm(rate ~/ 10), sampleRate: rate);
          yield TtsAudioStarted(TtsAudioFormat.fromFileBytes(wav, 'audio/wav'));
          yield TtsAudioChunk(wav);
          yield const TtsSynthesisCompleted();
        },
      );
      final events = await pipeline
          .run(
            Stream.fromIterable(['a。', 'b。']),
            cancellation: TtsCancelToken(),
          )
          .toList();
      final format = (events.first as TtsAudioStarted).format;
      expect(format.encoding, AudioEncoding.pcmS16le);
      expect(format.sampleRate, 48000);
      final bytes = events.whereType<TtsAudioChunk>().fold<int>(
        0,
        (n, e) => n + e.bytes.length,
      );
      // 100 ms + 100 ms at 48 kHz mono.
      expect(bytes, 2 * 4800 * 2);
    });

    test('each sentence is converted and streamed through VC', () async {
      final vc = _Vc();
      final pipeline = SentenceSpeechPipeline(
        speak: (s, _) async* {
          yield const TtsAudioStarted(
            TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: 24000,
              channels: 1,
            ),
          );
          yield TtsAudioChunk(_pcm(s.length * 240));
          yield const TtsSynthesisCompleted();
        },
        conversions: [VoiceConversionStage(vc, 'kikiV1')],
      );
      final events = await pipeline
          .run(
            Stream.fromIterable(['短。', '这一句要长得多才行。']),
            cancellation: TtsCancelToken(),
          )
          .toList();
      expect(vc.inputs, hasLength(2));
      // The 20 ms first sentence was padded to the 250 ms minimum clip.
      expect(parsePcmWav(vc.inputs.first).pcm.length, 24000 * 2 ~/ 4);
      expect((events.first as TtsAudioStarted).format.sampleRate, 40000);
      final chunks = events.whereType<TtsAudioChunk>().toList();
      expect(chunks, hasLength(4));
      expect(Int16List.sublistView(chunks.first.bytes).first, 7);
    });

    test('a failing sentence fails the stream and stops the rest', () async {
      final started = <String>[];
      final pipeline = SentenceSpeechPipeline(
        speak: (s, _) async* {
          started.add(s);
          if (s == 'bad.') throw StateError('TTS down');
          yield const TtsAudioStarted(
            TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: 24000,
              channels: 1,
            ),
          );
          yield TtsAudioChunk(_pcm(240));
          yield const TtsSynthesisCompleted();
        },
      );
      await expectLater(
        pipeline
            .run(
              Stream.fromIterable(['ok.', 'bad.', 'never.', 'never2.']),
              cancellation: TtsCancelToken(),
            )
            .toList(),
        throwsStateError,
      );
      expect(started, isNot(contains('never2.')));
    });

    test('cancellation stops generation', () async {
      final cancel = TtsCancelToken();
      final pipeline = SentenceSpeechPipeline(
        speak: (s, c) async* {
          yield const TtsAudioStarted(
            TtsAudioFormat(
              AudioEncoding.pcmS16le,
              sampleRate: 24000,
              channels: 1,
            ),
          );
          yield TtsAudioChunk(_pcm(240));
          cancel.cancel();
          c.throwIfCancelled();
        },
      );
      await expectLater(
        pipeline
            .run(Stream.fromIterable(['a.', 'b.']), cancellation: cancel)
            .toList(),
        throwsA(isA<TtsCancelledException>()),
      );
    });

    test('encoded audio without a decoder is rejected clearly', () async {
      final pipeline = SentenceSpeechPipeline(
        speak: (s, _) async* {
          yield const TtsAudioStarted(TtsAudioFormat(AudioEncoding.mp3));
          yield TtsAudioChunk(Uint8List.fromList([73, 68, 51, 4]));
          yield const TtsSynthesisCompleted();
        },
      );
      await expectLater(
        pipeline
            .run(Stream.value('a.'), cancellation: TtsCancelToken())
            .toList(),
        throwsA(
          isA<FormatException>().having((e) => e.message, 'm', contains('mp3')),
        ),
      );
    });
  });

  test('conformPcm resamples and remixes', () {
    final stereo = Int16List.fromList([10, 20, 30, 40]).buffer.asUint8List();
    final mono = conformPcm(
      stereo,
      fromRate: 8000,
      fromChannels: 2,
      toRate: 8000,
      toChannels: 1,
    );
    expect(Int16List.sublistView(mono), [15, 35]);
    final up = conformPcm(
      _pcm(100),
      fromRate: 8000,
      fromChannels: 1,
      toRate: 16000,
      toChannels: 2,
    );
    expect(up.length, 100 * 2 * 2 * 2);
  });
}
