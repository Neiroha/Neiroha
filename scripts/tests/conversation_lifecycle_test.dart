// Realtime calls and the companion over their whole life: hanging up
// during the handshake, a session that drops, interrupting a reply the
// server already finished, a failing voice conversion, and a microphone
// left open in silence.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/services/conversation/companion_conversation.dart';
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/realtime_conversation.dart';
import 'package:neiroha/data/services/conversation/reply_player.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

import 'support/fake_conversation_audio.dart';

const _d = ModelDescriptor(
  id: 'fake',
  capability: AiCapability.realtime,
  protocol: AiProtocol.native,
);

class _Session implements RealtimeSession {
  final events_ = StreamController<AiSessionEvent>();
  var frames = 0;
  var cancels = 0;
  var closed = false;
  @override
  Stream<AiSessionEvent> get events => events_.stream;
  @override
  int get inputSampleRate => 16000;
  @override
  void sendPcm(Uint8List pcm16) {
    if (closed) throw StateError('Session is closed.');
    frames++;
  }

  @override
  void sendText(String text) {}
  @override
  Future<ResponseDone> respond({Duration timeout = Duration.zero}) async =>
      const ResponseDone();
  @override
  void cancelResponse() => cancels++;
  @override
  Future<void> finish({Duration timeout = Duration.zero}) async {}
  @override
  Future<void> close() async {
    closed = true;
    // Not awaited: an unlistened controller's close never completes.
    if (!events_.isClosed) unawaited(events_.close());
  }
}

/// Connects when the test says so.
class _SlowRealtime implements RealtimeModel {
  final session = _Session();
  final gate = Completer<void>();
  @override
  ModelDescriptor get descriptor => _d;
  @override
  List<String> get voices => const [];
  @override
  Future<RealtimeSession> connect(RealtimeConfig config) async {
    await gate.future;
    return session;
  }
}

class _Mic extends FakeConversationAudio {
  var stops = 0;
  @override
  Future<void> stopMicrophone() async => stops++;
}

/// Speakers that keep playing until stopped.
class _Playing extends CollectingSink {
  @override
  Future<void> finish() async {}
}

class _PlayingIo extends FakeConversationAudio {
  @override
  StreamingAudioSink newSink() {
    final sink = _Playing();
    sinks.add(sink);
    return sink;
  }
}

class _FailingVc implements StreamingVoiceConverter {
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) => throw const AiProviderException('VC server is down');
  @override
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  }) => Stream.error(const AiProviderException('VC server is down'));
}

/// Ends one utterance at a fixed stream time once it has heard enough.
class _Vad implements VoiceActivityDetector, VadStream {
  _Vad(this.segment);
  final SpeechSegment segment;
  var _heard = Duration.zero;
  var _done = false;
  @override
  ModelDescriptor get descriptor => _d;
  @override
  VadStream open({
    required int sampleRate,
    VadConfig config = const VadConfig(),
  }) => this;
  @override
  List<SpeechSegment> segments(
    Uint8List pcm16, {
    required int sampleRate,
    VadConfig config = const VadConfig(),
  }) => const [];
  @override
  bool get inSpeech => false;
  @override
  List<SpeechSegment> feed(Uint8List pcm16) {
    _heard += Duration(microseconds: pcm16.length ~/ 2 * 1000000 ~/ 16000);
    if (_done || _heard < segment.end) return const [];
    _done = true;
    return [segment];
  }

  @override
  List<SpeechSegment> flush() => const [];
}

class _Transcriber implements Transcriber {
  final heard = <Uint8List>[];
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) async {
    heard.add(audio.bytes);
    return const Transcript('');
  }
}

class _Llm implements LanguageModel {
  @override
  ModelDescriptor get descriptor => _d;
  @override
  Future<String> complete(
    List<LlmChatMessage> messages, {
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) async => '';
  @override
  Future<LlmStructuredResult> structured(
    List<LlmChatMessage> messages, {
    required String schemaName,
    required Map<String, Object?> schema,
    TtsCancelToken? cancellation,
    int maxOutputTokens = 4096,
  }) => throw UnimplementedError();
}

const _pcm24k = TtsAudioFormat(
  AudioEncoding.pcmS16le,
  sampleRate: 24000,
  channels: 1,
);

void main() {
  test('hanging up during the handshake never opens the call', () async {
    final model = _SlowRealtime();
    final io = _Mic();
    final engine = RealtimeConversation(model: model, io: io, instructions: '');
    final starting = engine.start();
    await pumpEventQueue();
    await engine.stop();
    model.gate.complete();
    await starting;
    io.mic.add(Uint8List(320));
    await pumpEventQueue();
    expect(model.session.closed, isTrue);
    expect(model.session.frames, 0);
  });

  test('a dropped session ends the call and frees the microphone', () async {
    final model = _SlowRealtime()..gate.complete();
    final io = _Mic();
    final engine = RealtimeConversation(model: model, io: io, instructions: '');
    final events = <ConversationEvent>[];
    engine.events.listen(events.add);
    await engine.start();
    model.session.events_.add(const ResponseDone(text: 'hi'));
    await pumpEventQueue();
    model.session.events_.addError(StateError('socket closed'));
    await pumpEventQueue();
    expect(events.whereType<ConversationFailed>(), hasLength(1));
    expect(
      events.whereType<ConversationStateChanged>().last.state,
      ConversationState.idle,
    );
    expect(io.stops, 1);
    expect(model.session.closed, isTrue);
    // A late frame no longer reaches the closed socket.
    io.mic.add(Uint8List(320));
    await pumpEventQueue();
    await engine.stop();
  });

  test('events still queued at hang-up open no player', () async {
    final model = _SlowRealtime()..gate.complete();
    final io = FakeConversationAudio();
    final engine = RealtimeConversation(model: model, io: io, instructions: '');
    await engine.start();
    for (var i = 0; i < 3; i++) {
      model.session.events_.add(
        AudioDelta(Uint8List(4800), sampleRate: 24000, itemId: 'a'),
      );
    }
    await engine.stop();
    await pumpEventQueue();
    expect(io.sinks, isEmpty);
  });

  test('typing over a finished reply stops playback, not the server', () async {
    final model = _SlowRealtime()..gate.complete();
    final engine = RealtimeConversation(
      model: model,
      io: _PlayingIo(),
      instructions: '',
    );
    await engine.start();
    model.session.events_
      ..add(AudioDelta(Uint8List(4800), sampleRate: 24000, itemId: 'a'))
      ..add(const ResponseDone(text: 'done'));
    await pumpEventQueue();
    await engine.sendText('wait');
    expect(model.session.cancels, 0);

    model.session.events_.add(
      AudioDelta(Uint8List(4800), sampleRate: 24000, itemId: 'b'),
    );
    await pumpEventQueue();
    await engine.sendText('stop');
    expect(model.session.cancels, 1);
    await engine.stop();
  });

  test('a failing phrase conversion surfaces its own error', () async {
    final io = FakeConversationAudio();
    final player = ReplyPlayer(
      io,
      conversion: VoiceConversionStage(_FailingVc(), 'v'),
    );
    await player.begin(_pcm24k);
    await player.add(Uint8List(24000 * 2));
    await expectLater(
      player.end(),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.message,
          'message',
          'VC server is down',
        ),
      ),
    );
  });

  test('silence before speaking is not kept, the utterance is', () async {
    // Speech from 59.5 s to 60.5 s after a minute of waiting.
    final stt = _Transcriber();
    final engine = CompanionConversation(
      vad: _Vad(
        const SpeechSegment(
          Duration(milliseconds: 59500),
          Duration(milliseconds: 60500),
        ),
      ),
      transcriber: stt,
      llm: _Llm(),
      speak: (_, _) => const Stream.empty(),
      io: FakeConversationAudio(),
      systemPrompt: '',
    );
    // 100 ms frames; each sample holds its frame number.
    for (var frame = 0; frame < 606; frame++) {
      engine.onAudioForTest(
        Int16List.fromList(List.filled(1600, frame)).buffer.asUint8List(),
      );
    }
    await pumpEventQueue();
    final wav = stt.heard.single;
    final samples = Int16List.sublistView(wav, 44);
    expect(samples.length, 16000);
    expect(samples.first, 595);
    expect(samples.last, 604);
    await engine.stop();
  });
}
