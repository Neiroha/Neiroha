import 'dart:convert';
import 'dart:typed_data';

/// Whether [bytes] already start with a RIFF header.
bool isRiffWav(Uint8List bytes) =>
    bytes.length > 12 &&
    bytes[0] == 0x52 &&
    bytes[1] == 0x49 &&
    bytes[2] == 0x46 &&
    bytes[3] == 0x46;

/// Wrap raw little-endian PCM into a minimal RIFF/WAVE container.
Uint8List wrapPcmAsWav(
  Uint8List pcm, {
  int sampleRate = 24000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLen = pcm.length;
  final buf = BytesBuilder();
  void w32(int v) =>
      buf.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  void w16(int v) => buf.add([v & 0xff, (v >> 8) & 0xff]);
  buf.add(ascii.encode('RIFF'));
  w32(36 + dataLen);
  buf.add(ascii.encode('WAVE'));
  buf.add(ascii.encode('fmt '));
  w32(16);
  w16(1); // PCM
  w16(channels);
  w32(sampleRate);
  w32(byteRate);
  w16(blockAlign);
  w16(bitsPerSample);
  buf.add(ascii.encode('data'));
  w32(dataLen);
  buf.add(pcm);
  return buf.toBytes();
}
