import 'dart:typed_data';

/// Linear-interpolation resampler for PCM16 mono (e.g. 48 kHz microphone →
/// 24 kHz Realtime / 16 kHz STT). Good enough for speech.
Uint8List resamplePcm16(Uint8List pcm, int fromRate, int toRate) {
  if (fromRate == toRate || pcm.length < 2) return pcm;
  final aligned = pcm.offsetInBytes.isEven ? pcm : Uint8List.fromList(pcm);
  final input = Int16List.sublistView(aligned, 0, aligned.length & ~1);
  final outLength = (input.length * toRate / fromRate).floor();
  final out = Int16List(outLength);
  final step = fromRate / toRate;
  for (var i = 0; i < outLength; i++) {
    final x = i * step;
    final j = x.floor();
    final next = j + 1 < input.length ? input[j + 1] : input[j];
    out[i] = (input[j] + (next - input[j]) * (x - j)).round();
  }
  return out.buffer.asUint8List();
}
