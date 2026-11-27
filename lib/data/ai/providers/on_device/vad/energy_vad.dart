import 'dart:typed_data';

import 'package:neiroha/domain/ai/media/speech_segment.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/voice_activity_detector.dart';

import 'energy_vad_stream.dart';

/// Energy VAD for whole files ([segments]) and live audio ([open]).
class EnergyVad implements VoiceActivityDetector {
  const EnergyVad(this.descriptor);
  @override
  final ModelDescriptor descriptor;

  @override
  VadStream open({
    required int sampleRate,
    VadConfig config = const VadConfig(),
  }) => EnergyVadStream(sampleRate: sampleRate, config: config);

  /// Padded utterances, clamped to the audio and merged where they overlap.
  @override
  List<SpeechSegment> segments(
    Uint8List pcm16, {
    required int sampleRate,
    VadConfig config = const VadConfig(),
  }) {
    if (sampleRate <= 0) throw ArgumentError('sampleRate must be positive.');
    final stream = EnergyVadStream(sampleRate: sampleRate, config: config);
    final total = Duration(
      microseconds: pcm16.lengthInBytes ~/ 2 * 1000000 ~/ sampleRate,
    );
    final result = <SpeechSegment>[];
    for (final raw in [...stream.feed(pcm16), ...stream.flush()]) {
      final s = SpeechSegment(raw.start, raw.end > total ? total : raw.end);
      if (result.isNotEmpty && s.start <= result.last.end) {
        result.last = SpeechSegment(result.last.start, s.end);
      } else {
        result.add(s);
      }
    }
    return result;
  }
}
