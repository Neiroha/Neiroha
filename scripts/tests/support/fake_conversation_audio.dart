import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// Collects one reply; finish() counts as fully played.
class CollectingSink implements StreamingAudioSink {
  final bytes = BytesBuilder(copy: false);
  final _drained = Completer<void>();
  TtsAudioFormat? format;
  bool stopped = false;
  @override
  Future<void> open(TtsAudioFormat f) async => format = f;
  @override
  Future<void> add(Uint8List b) async => bytes.add(b);
  @override
  Future<void> finish() async {
    if (!_drained.isCompleted) _drained.complete();
  }

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_drained.isCompleted) _drained.complete();
  }

  @override
  Future<void> get drained => _drained.future;
  @override
  Future<void> pause(bool paused) async {}
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedUntil => Duration.zero;
  @override
  bool get isBuffering => false;
}

/// Microphone fed by the test (16 kHz) and collecting speakers.
class FakeConversationAudio implements ConversationAudioIo {
  final mic = StreamController<Uint8List>();
  final sinks = <CollectingSink>[];
  @override
  int get microphoneRate => 16000;
  @override
  Future<Stream<Uint8List>> startMicrophone() async => mic.stream;
  @override
  Future<void> stopMicrophone() async {}
  @override
  StreamingAudioSink newSink() {
    final sink = CollectingSink();
    sinks.add(sink);
    return sink;
  }

  @override
  Future<void> dispose() async {}
}
