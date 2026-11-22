import 'dart:math' as math;
import 'dart:typed_data';

import 'package:neiroha/domain/ai/media/speech_segment.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/voice_activity_detector.dart';

/// RMS-per-frame detector with hangover, minimum speech length and padding.
class EnergyVad implements VoiceActivityDetector {
  const EnergyVad(this.descriptor);
  @override
  final ModelDescriptor descriptor;

  @override
  List<SpeechSegment> segments(
    Uint8List pcm16, {
    required int sampleRate,
    VadConfig config = const VadConfig(),
  }) {
    if (sampleRate <= 0) throw ArgumentError('sampleRate must be positive.');
    final samples = pcm16.buffer.asByteData(
      pcm16.offsetInBytes,
      pcm16.lengthInBytes & ~1,
    );
    final total = samples.lengthInBytes ~/ 2;
    final frame = math.max(1, sampleRate * config.frame.inMicroseconds ~/ 1e6);
    Duration at(int sample) =>
        Duration(microseconds: sample * 1000000 ~/ sampleRate);
    final threshold = math.pow(10, config.thresholdDb / 20) * 32768;

    final raw = <(int, int)>[];
    int? start;
    var lastVoice = 0;
    final silenceFrames =
        config.minSilence.inMicroseconds * sampleRate ~/ 1e6 ~/ frame;
    for (var offset = 0; offset < total; offset += frame) {
      final end = math.min(total, offset + frame);
      var sum = 0.0;
      for (var i = offset; i < end; i++) {
        final s = samples.getInt16(i * 2, Endian.little);
        sum += s * s;
      }
      final voiced = math.sqrt(sum / (end - offset)) >= threshold;
      if (voiced) {
        start ??= offset;
        lastVoice = end;
      } else if (start != null && (end - lastVoice) ~/ frame >= silenceFrames) {
        raw.add((start, lastVoice));
        start = null;
      }
    }
    if (start != null) raw.add((start, lastVoice));

    final pad = config.padding.inMicroseconds * sampleRate ~/ 1e6;
    final minSpeech = config.minSpeech.inMicroseconds * sampleRate ~/ 1e6;
    final result = <SpeechSegment>[];
    for (final (s, e) in raw) {
      if (e - s < minSpeech) continue;
      final padded = (math.max(0, s - pad), math.min(total, e + pad));
      if (result.isNotEmpty && at(padded.$1) <= result.last.end) {
        result.last = SpeechSegment(result.last.start, at(padded.$2));
      } else {
        result.add(SpeechSegment(at(padded.$1), at(padded.$2)));
      }
    }
    return result;
  }
}
