import 'dart:typed_data';

import 'package:neiroha/domain/ai/media/speech_segment.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

class VadConfig {
  const VadConfig({
    this.thresholdDb = -40,
    this.frame = const Duration(milliseconds: 30),
    this.minSpeech = const Duration(milliseconds: 200),
    this.minSilence = const Duration(milliseconds: 300),
    this.padding = const Duration(milliseconds: 100),
  });
  final double thresholdDb;
  final Duration frame;
  final Duration minSpeech;
  final Duration minSilence;
  final Duration padding;
}

/// Incremental detection for live microphone audio. Times are measured from
/// the first fed sample.
abstract interface class VadStream {
  /// Feeds PCM16 mono and returns the utterances that ended in this chunk.
  List<SpeechSegment> feed(Uint8List pcm16);

  /// True while an utterance is in progress (speech started, not yet ended).
  bool get inSpeech;

  /// Ends input and returns the utterance still in progress, if any.
  List<SpeechSegment> flush();
}

abstract interface class VoiceActivityDetector implements CapabilityModel {
  List<SpeechSegment> segments(
    Uint8List pcm16, {
    required int sampleRate,
    VadConfig config,
  });

  VadStream open({required int sampleRate, VadConfig config});
}
