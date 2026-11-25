part of 'ffmpeg_service.dart';

// DirectShow input listing and waveform peak reduction.

class DshowAudioInput {
  final String name;
  final String? alternativeName;

  const DshowAudioInput({required this.name, this.alternativeName});

  /// Prefer the friendly name for recording. Some FFmpeg builds list
  /// `@device_cm_...\wave_...` alternative names that enumerate correctly
  /// but fail to open as DirectShow capture inputs.
  List<String> get recordingNames => [
    name,
    if (alternativeName != null && alternativeName != name) alternativeName!,
  ];
}

/// Streaming reducer for little-endian signed 16-bit PCM. Feed arbitrary
/// byte chunks via [addBytes]; call [finish] once to flush the running
/// peak into the final bucket.
///
/// Each bucket holds the max absolute amplitude of its sample window,
/// scaled to [0.0, 1.0].
@visibleForTesting
class PeakReducer {
  PeakReducer(this.sampleCount, this.bucketCount)
    : _peaks = List<double>.filled(bucketCount, 0.0),
      _boundaries = _computeBoundaries(sampleCount, bucketCount);

  final int sampleCount;
  final int bucketCount;
  final List<double> _peaks;
  final List<int> _boundaries;

  int _sampleIdx = 0;
  int _bucketIdx = 0;
  int _peak = 0;
  int _pendingLow = -1;

  static List<int> _computeBoundaries(int sampleCount, int bucketCount) {
    if (bucketCount <= 0 || sampleCount <= 0) return const [];
    final bucketSize = sampleCount / bucketCount;
    final out = List<int>.filled(bucketCount, 0);
    for (var i = 0; i < bucketCount; i++) {
      final start = (i * bucketSize).floor();
      out[i] = ((i + 1) * bucketSize).floor().clamp(start + 1, sampleCount);
    }
    return out;
  }

  void addBytes(List<int> chunk) {
    if (bucketCount <= 0 || _boundaries.isEmpty) return;
    var i = 0;
    if (_pendingLow >= 0 && chunk.isNotEmpty) {
      _addSample(_pendingLow, chunk[0]);
      _pendingLow = -1;
      i = 1;
    }
    while (i + 1 < chunk.length) {
      _addSample(chunk[i], chunk[i + 1]);
      i += 2;
    }
    if (i < chunk.length) {
      _pendingLow = chunk[i];
    }
  }

  void _addSample(int lo, int hi) {
    if (_bucketIdx >= bucketCount) return;
    var value = (hi << 8) | lo;
    if (value >= 0x8000) value -= 0x10000;
    final abs = value.abs();
    if (abs > _peak) _peak = abs;
    _sampleIdx++;
    if (_sampleIdx >= _boundaries[_bucketIdx]) {
      _peaks[_bucketIdx] = _peak / 32768.0;
      _bucketIdx++;
      _peak = 0;
    }
  }

  List<double> finish() {
    if (_bucketIdx < bucketCount) {
      _peaks[_bucketIdx] = _peak / 32768.0;
    }
    return _peaks;
  }
}
