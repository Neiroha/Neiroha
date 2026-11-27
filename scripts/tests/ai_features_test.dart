import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/protocols/audio/pcm_resample.dart';
import 'package:neiroha/data/ai/providers/on_device/on_device_plugin.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/realtime_conversation.dart';
import 'package:neiroha/data/services/conversation/reply_player.dart';
import 'package:neiroha/data/services/subtitles/segment_planner.dart';
import 'package:neiroha/data/services/subtitles/subtitle_cue.dart';
import 'package:neiroha/data/services/subtitles/subtitle_pipeline.dart';
import 'package:neiroha/data/services/subtitles/subtitle_translator.dart';
import 'package:neiroha/data/services/subtitles/subtitle_writer.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

import 'support/fake_conversation_audio.dart';

const _d = ModelDescriptor(
  id: 'fake',
  capability: AiCapability.stt,
  protocol: AiProtocol.native,
);

Duration _ms(int v) => Duration(milliseconds: v);

/// PCM16 mono: (ms, amplitude) parts of a 440 Hz tone or silence.
Uint8List _pcm(List<(int, double)> parts, {int rate = 16000}) {
  final out = BytesBuilder();
  for (final (ms, a) in parts) {
    final data = ByteData(rate * ms ~/ 1000 * 2);
    for (var i = 0; i < data.lengthInBytes ~/ 2; i++) {
      data.setInt16(
        i * 2,
        (a * 32767 * math.sin(2 * math.pi * 440 * i / rate)).round(),
        Endian.little,
      );
    }
    out.add(data.buffer.asUint8List());
  }
  return out.takeBytes();
}

class _Stt implements Transcriber {
  _Stt(this.reply);
  final String Function(int call) reply;
  int calls = 0;
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) async => Transcript(reply(calls++));
}

class _Llm implements LanguageModel {
  _Llm({this.text = 'ok', this.lines});
  final String text;
  final List<List<String>>? lines;
  final prompts = <List<LlmChatMessage>>[];
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    prompts.add(messages);
    return text;
  }

  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async {
    prompts.add(messages);
    return LlmStructuredResult({
      'lines': lines![prompts.length - 1],
    }, finishReason: 'stop');
  }
}

class _Vc implements VoiceConverter {
  AudioInput? got;
  String? voice;
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) async {
    got = audio;
    voice = targetVoice;
    return TtsResult(
      audioBytes: Uint8List.fromList([73, 68, 51, 4, 0, 0]),
      contentType: 'audio/mpeg',
    );
  }
}

class _StreamLlm extends _Llm implements StreamingLanguageModel {
  final deltas = StreamController<String>();
  @override
  Stream<String> streamText(
    List<LlmChatMessage> messages, {
    required TtsCancelToken cancellation,
    int maxOutputTokens = 4096,
  }) => deltas.stream;
}

class _StreamVc extends _Vc implements StreamingVoiceConverter {
  var calls = 0;
  @override
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  }) async* {
    calls++;
    yield const TtsAudioStarted(
      TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 40000, channels: 1),
    );
    yield TtsAudioChunk(Uint8List(8000));
    yield const TtsSynthesisCompleted();
  }
}

Stream<TtsEvent> _speech(String text, TtsCancelToken _) async* {
  yield const TtsAudioStarted(
    TtsAudioFormat(AudioEncoding.pcmS16le, sampleRate: 24000, channels: 1),
  );
  yield TtsAudioChunk(Uint8List(4800));
  yield const TtsSynthesisCompleted();
}

void main() {
  group('subtitles', () {
    const cues = [
      SubtitleCue(Duration(milliseconds: 1500), Duration(seconds: 3), 'Hi'),
      SubtitleCue(
        Duration(minutes: 61, milliseconds: 5),
        Duration(minutes: 61, seconds: 2),
        'Bye',
        translation: '再见',
      ),
    ];

    test('SRT, VTT and LRC writers', () {
      expect(
        writeSubtitles(cues, SubtitleFormat.srt),
        '1\n00:00:01,500 --> 00:00:03,000\nHi\n\n'
        '2\n01:01:00,005 --> 01:01:02,000\nBye\n\n',
      );
      expect(
        writeSubtitles(
          cues,
          SubtitleFormat.vtt,
          mode: SubtitleTextMode.bilingual,
        ),
        startsWith('WEBVTT\n\n00:00:01.500 --> 00:00:03.000\nHi\n\n'),
      );
      expect(
        writeSubtitles(
          cues,
          SubtitleFormat.vtt,
          mode: SubtitleTextMode.bilingual,
        ),
        contains('Bye\n再见'),
      );
      expect(
        writeSubtitles(
          cues,
          SubtitleFormat.lrc,
          mode: SubtitleTextMode.translation,
        ),
        '[00:01.50]Hi\n[61:00.00]再见\n',
      );
    });

    test('planner merges close utterances and splits long ones', () {
      final chunks = planSubtitleChunks([
        SpeechSegment(_ms(0), _ms(1000)),
        SpeechSegment(_ms(1200), _ms(2000)),
        SpeechSegment(_ms(5000), _ms(25000)),
      ]);
      expect(chunks.map((c) => (c.start, c.end)), [
        (_ms(0), _ms(2000)),
        (_ms(5000), const Duration(microseconds: 11666666)),
        (
          const Duration(microseconds: 11666666),
          const Duration(microseconds: 18333332),
        ),
        (const Duration(microseconds: 18333332), _ms(25000)),
      ]);
    });

    test('translator retries a batch with the wrong line count', () async {
      final llm = _Llm(
        lines: [
          ['only one'],
          ['你好', '再见'],
        ],
      );
      final out = await SubtitleTranslator(
        llm,
      ).translate(['Hello', 'Bye'], targetLanguage: 'Chinese');
      expect(out, ['你好', '再见']);
      expect(llm.prompts, hasLength(2));
      expect(llm.prompts.first.last.content, '1. Hello\n2. Bye');
    });

    test('pipeline: VAD chunks → STT → translation with timings', () async {
      final stt = _Stt((i) => i == 1 ? '' : 'line $i');
      final pipeline = SubtitlePipeline(
        decode: (_, _) async => _pcm([
          (500, 0),
          (1000, 0.3),
          (1500, 0),
          (800, 0.3),
          (1500, 0),
          (900, 0.3),
          (500, 0),
        ]),
        vad: OnDevicePlugin.builtIn().vad()!,
        transcriber: stt,
        translator: SubtitleTranslator(
          _Llm(
            lines: [
              ['第0行', '第2行'],
            ],
          ),
        ),
        concurrency: 1,
      );
      final stages = <SubtitleStage>[];
      final cues = await pipeline.run(
        const SubtitleJob('x.mp4', targetLanguage: 'Chinese'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(stt.calls, 3);
      expect(cues.map((c) => c.text), ['line 0', 'line 2']); // empty dropped
      expect(cues.map((c) => c.translation), ['第0行', '第2行']);
      expect(cues.first.start.inMilliseconds, closeTo(400, 40));
      expect(stages.first, SubtitleStage.decoding);
      expect(stages.last, SubtitleStage.done);
      expect(stages, contains(SubtitleStage.translating));
    });
  });

  test('resampler halves 48 kHz to 24 kHz', () {
    final pcm = _pcm([(100, 0.5)], rate: 48000);
    expect(resamplePcm16(pcm, 48000, 24000).length, pcm.length ~/ 2);
    expect(resamplePcm16(pcm, 48000, 48000), same(pcm));
  });

  group('companion conversation', () {
    test('hears an utterance, answers in character and speaks', () async {
      final io = FakeConversationAudio();
      final llm = _Llm(text: 'Hello, commander.');
      final engine = CompanionConversation(
        vad: OnDevicePlugin.builtIn().vad()!,
        transcriber: _Stt((_) => 'hi there'),
        llm: llm,
        speak: _speech,
        io: io,
        systemPrompt: 'You are Nagato.',
      );
      final events = <ConversationEvent>[];
      engine.events.listen(events.add);
      await engine.start();
      engine.onAudioForTest(_pcm([(300, 0), (800, 0.3), (600, 0)]));
      await pumpEventQueue();
      expect(events.whereType<UserTurn>().single.text, 'hi there');
      // Streamed deltas, then the final text.
      final turns = events.whereType<CharacterTurn>().toList();
      expect(
        turns.where((t) => !t.done).map((t) => t.text).join(),
        'Hello, commander.',
      );
      expect(turns.last.done, isTrue);
      expect(turns.last.text, 'Hello, commander.');
      expect(llm.prompts.single.first.content, startsWith('You are Nagato.'));
      expect(io.sinks.single.bytes.length, 4800);
      expect(
        events.whereType<ConversationStateChanged>().last.state,
        ConversationState.listening,
      );
      await engine.sendText('and now?');
      expect(llm.prompts.last.map((m) => m.role), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      await engine.stop();
    });

    test('a file-only VC without a decoder converts the whole reply', () async {
      final io = FakeConversationAudio();
      final vc = _Vc();
      final engine = CompanionConversation(
        vad: OnDevicePlugin.builtIn().vad()!,
        transcriber: _Stt((_) => ''),
        llm: _Llm(text: 'Converted line.'),
        speak: _speech,
        io: io,
        systemPrompt: 'x',
        conversion: VoiceConversionStage(vc, 'voice-123'),
      );
      await engine.start();
      await engine.sendText('hi');
      expect(vc.voice, 'voice-123');
      expect(vc.got!.contentType, 'audio/wav');
      expect(vc.got!.bytes.length, 4800 + 44);
      expect(io.sinks.single.format!.encoding, AudioEncoding.mp3);
      await engine.stop();
    });
  });

  group('companion streaming', () {
    test('each sentence is spoken while the LLM is still writing', () async {
      final io = FakeConversationAudio();
      final llm = _StreamLlm();
      final spoken = <String>[];
      final engine = CompanionConversation(
        vad: OnDevicePlugin.builtIn().vad()!,
        transcriber: _Stt((_) => ''),
        llm: llm,
        speak: (text, c) {
          spoken.add(text);
          return _speech(text, c);
        },
        io: io,
        systemPrompt: 'x',
      );
      await engine.start();
      final turn = engine.sendText('hi');
      llm.deltas.add('指挥官，');
      llm.deltas.add('欢迎回来。今天');
      await pumpEventQueue();
      expect(spoken, ['指挥官，欢迎回来。']);
      expect(io.sinks.single.bytes.length, 4800);
      llm.deltas.add('也辛苦了。');
      await llm.deltas.close();
      await turn;
      expect(spoken, ['指挥官，欢迎回来。', '今天也辛苦了。']);
      expect(io.sinks.single.bytes.length, 9600);
      await engine.stop();
    });

    test('a streaming VC converts sentence by sentence', () async {
      final io = FakeConversationAudio();
      final vc = _StreamVc();
      final engine = CompanionConversation(
        vad: OnDevicePlugin.builtIn().vad()!,
        transcriber: _Stt((_) => ''),
        llm: _Llm(text: '第一句。第二句。'),
        speak: _speech,
        io: io,
        systemPrompt: 'x',
        conversion: VoiceConversionStage(vc, 'kikiV1'),
      );
      await engine.start();
      await engine.sendText('hi');
      expect(vc.calls, 2);
      expect(io.sinks.single.format!.sampleRate, 40000);
      await engine.stop();
    });
  });

  group('realtime conversation', () {
    test('streams replies and stops playback on barge-in', () async {
      final io = FakeConversationAudio();
      final session = _Session();
      final engine = RealtimeConversation(
        model: _Realtime(session),
        io: io,
        instructions: 'You are Nagato.',
        voice: 'marin',
      );
      final events = <ConversationEvent>[];
      engine.events.listen(events.add);
      await engine.start();
      expect(session.config!.serverVad, isTrue);
      expect(session.config!.instructions, 'You are Nagato.');

      io.mic.add(Uint8List(3200));
      await pumpEventQueue();
      expect(session.sent, 3200 * 24000 ~/ 16000);

      session.emit(const TranscriptFinal('hello'));
      session.emit(AudioDelta(Uint8List(960), sampleRate: 24000));
      session.emit(const TranscriptDelta('Hi'));
      await pumpEventQueue();
      io.mic.add(Uint8List(3200)); // muted while speaking
      await pumpEventQueue();
      expect(session.sent, 4800);
      session.emit(const ResponseDone(text: 'Hi'));
      await pumpEventQueue();
      expect(io.sinks.single.bytes.length, 960);
      expect(events.whereType<UserTurn>().single.text, 'hello');

      session.emit(AudioDelta(Uint8List(960), sampleRate: 24000));
      await pumpEventQueue();
      session.emit(const SpeechStarted());
      await pumpEventQueue();
      expect(io.sinks.last.stopped, isTrue);
      expect(session.cancelled, 1);
      await engine.stop();
      expect(session.closed, isTrue);
    });
  });
}

class _Realtime implements RealtimeModel {
  _Realtime(this.session);
  final _Session session;
  @override
  ModelDescriptor get descriptor => _d;
  @override
  List<String> get voices => const ['marin'];
  @override
  Future<RealtimeSession> connect(RealtimeConfig config) async {
    session.config = config;
    return session;
  }
}

class _Session implements RealtimeSession {
  final _events = StreamController<AiSessionEvent>();
  RealtimeConfig? config;
  int sent = 0;
  int cancelled = 0;
  bool closed = false;
  void emit(AiSessionEvent e) => _events.add(e);
  @override
  Stream<AiSessionEvent> get events => _events.stream;
  @override
  int get inputSampleRate => 24000;
  @override
  void sendPcm(Uint8List pcm16) => sent += pcm16.length;
  @override
  void sendText(String text) {}
  @override
  Future<ResponseDone> respond({Duration timeout = Duration.zero}) async =>
      const ResponseDone();
  @override
  void cancelResponse() => cancelled++;
  @override
  Future<void> finish({Duration timeout = Duration.zero}) async {}
  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
  }
}
