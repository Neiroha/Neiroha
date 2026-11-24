import 'dart:math' as math;
import 'dart:typed_data';

/// Cuts a live PCM16 mono stream into clips at short pauses, so a converter
/// can work on one phrase while the next is still arriving. A clip ends at
/// the first quiet stretch after [minMs], or hard at [maxMs].
class PcmSegmenter {
  PcmSegmenter({
    required this.sampleRate,
    this.minMs = 1200,
    this.maxMs = 4000,
    this.quietMs = 120,
    this.quietRms = 400,
  });

  final int sampleRate;
  final int minMs;
  final int maxMs;

  /// How long the signal must stay below [quietRms] to count as a pause.
  final int quietMs;
  final double quietRms;

  final _pending = BytesBuilder(copy: true);

  int get _frameBytes => sampleRate ~/ 100 * 2; // 10 ms
  int _bytesFor(int ms) => sampleRate * ms ~/ 1000 * 2;

  /// Adds audio; returns the clips completed by it, in order.
  List<Uint8List> add(Uint8List pcm) {
    _pending.add(pcm);
    final out = <Uint8List>[];
    while (true) {
      final cut = _cutPoint(_pending.toBytes());
      if (cut == null) break;
      final all = _pending.takeBytes();
      out.add(Uint8List.sublistView(all, 0, cut));
      _pending.add(Uint8List.sublistView(all, cut));
    }
    return out;
  }

  /// The rest of the stream as a last clip (null when nothing is left).
  Uint8List? flush() {
    final rest = _pending.takeBytes();
    return rest.isEmpty ? null : rest;
  }

  /// Byte offset to cut at: the middle of the first pause after [minMs], or
  /// [maxMs] when there is none; null while the clip is still too short.
  int? _cutPoint(Uint8List bytes) {
    final frame = _frameBytes;
    final min = _bytesFor(minMs);
    final max = _bytesFor(maxMs);
    final needQuiet = math.max(1, quietMs ~/ 10);
    var quiet = 0;
    for (var at = min; at + frame <= bytes.length; at += frame) {
      if (_rms(bytes, at, frame) < quietRms) {
        quiet++;
        if (quiet >= needQuiet) {
          // Cut in the middle of the pause, frame-aligned.
          return at + frame - (quiet ~/ 2) * frame;
        }
      } else {
        quiet = 0;
      }
      if (at + frame >= max) return max;
    }
    return bytes.length >= max ? max : null;
  }

  static double _rms(Uint8List bytes, int start, int length) {
    final view = ByteData.sublistView(bytes, start, start + length);
    var sum = 0.0;
    final n = length ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = view.getInt16(i * 2, Endian.little);
      sum += s * s;
    }
    return n == 0 ? 0 : math.sqrt(sum / n);
  }
}
