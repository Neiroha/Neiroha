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

abstract interface class VoiceActivityDetector implements CapabilityModel {
  List<SpeechSegment> segments(
    Uint8List pcm16, {
    required int sampleRate,
    VadConfig config,
  });
}
