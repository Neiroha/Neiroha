import 'dart:math' as math;
import 'dart:typed_data';

import 'package:neiroha/domain/ai/media/speech_segment.dart';
import 'package:neiroha/domain/ai/models/voice_activity_detector.dart';

/// Frame-RMS detector with hangover ([VadConfig.minSilence]), a minimum
/// utterance length and padding. Feed it any chunk size.
class EnergyVadStream implements VadStream {
  EnergyVadStream({required this.sampleRate, this.config = const VadConfig()})
    : assert(sampleRate > 0) {
    _frame = math.max(1, _samples(config.frame));
    _threshold = math.pow(10, config.thresholdDb / 20) * 32768;
  }

  final int sampleRate;
  final VadConfig config;
  late final int _frame;
  late final double _threshold;
  final _pending = BytesBuilder(copy: false);
  int _position = 0; // samples consumed, always a frame multiple
  int? _start;
  int _lastVoice = 0;

  int _samples(Duration d) => d.inMicroseconds * sampleRate ~/ 1000000;
  Duration _at(int sample) =>
      Duration(microseconds: sample * 1000000 ~/ sampleRate);

  @override
  bool get inSpeech =>
      _start != null && _lastVoice - _start! >= _samples(config.minSpeech);

  @override
  List<SpeechSegment> feed(Uint8List pcm16) {
    _pending.add(pcm16);
    final bytes = _pending.takeBytes();
    final usable = bytes.length - bytes.length % (_frame * 2);
    final ended = <SpeechSegment>[];
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset < usable; offset += _frame * 2) {
      var sum = 0.0;
      for (var i = 0; i < _frame; i++) {
        final s = data.getInt16(offset + i * 2, Endian.little);
        sum += s * s;
      }
      final frameEnd = _position + _frame;
      if (math.sqrt(sum / _frame) >= _threshold) {
        _start ??= _position;
        _lastVoice = frameEnd;
      } else if (_start != null &&
          frameEnd - _lastVoice >= _samples(config.minSilence)) {
        ended.addAll(_close());
      }
      _position = frameEnd;
    }
    if (usable < bytes.length) _pending.add(bytes.sublist(usable));
    return ended;
  }

  @override
  List<SpeechSegment> flush() => _start == null ? const [] : _close();

  List<SpeechSegment> _close() {
    final start = _start!;
    _start = null;
    if (_lastVoice - start < _samples(config.minSpeech)) return const [];
    final pad = _samples(config.padding);
    return [
      SpeechSegment(_at(math.max(0, start - pad)), _at(_lastVoice + pad)),
    ];
  }
}
