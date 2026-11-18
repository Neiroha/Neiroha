import 'dart:async';
import 'dart:typed_data';
import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

class MemoryAudioSink implements StreamingAudioSink {
  final bytes = BytesBuilder(copy: false);
  final firstChunk = Completer<void>();
  final playbackEnded = Completer<void>();
  TtsAudioFormat? format;
  bool finished = false;
  bool stopped = false;
  @override
  Future<void> open(TtsAudioFormat value) async => format = value;
  @override
  Future<void> add(Uint8List data) async {
    bytes.add(data);
    if (!firstChunk.isCompleted) firstChunk.complete();
  }

  @override
  Future<void> finish() async => finished = true;
  @override
  Future<void> stop() async {
    stopped = true;
    if (!playbackEnded.isCompleted) playbackEnded.complete();
  }

  @override
  Future<void> pause(bool paused) async {}
  @override
  Future<void> get drained => playbackEnded.future;
  @override
  bool get isBuffering => false;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get bufferedUntil => Duration(
    microseconds:
        bytes.length *
        1000000 ~/
        ((format?.sampleRate ?? 24000) * (format?.channels ?? 1) * 2),
  );
}
