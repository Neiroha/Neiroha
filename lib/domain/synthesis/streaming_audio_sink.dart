import 'dart:typed_data';

import 'tts_event.dart';

/// One instance per utterance. Completion means speakers drained, not EOF.
abstract interface class StreamingAudioSink {
  Future<void> open(TtsAudioFormat format);
  Future<void> add(Uint8List bytes);
  Future<void> finish();
  Future<void> get drained;
  Future<void> pause(bool paused);
  Future<void> stop();
  Duration get position;
  Duration get bufferedUntil;
  bool get isBuffering;
}
