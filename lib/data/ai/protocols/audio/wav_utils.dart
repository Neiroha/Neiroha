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

/// 16-bit PCM samples and layout read from a RIFF/WAVE file.
typedef WavPcm = ({Uint8List pcm, int sampleRate, int channels});

/// Reads a 16-bit PCM WAV, skipping non-audio chunks. Streamed WAVs whose
/// data size is 0 or 0xFFFFFFFF run to the end of the file.
WavPcm parsePcmWav(Uint8List bytes) {
  if (!isRiffWav(bytes) ||
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
    throw const FormatException('Not a WAV file.');
  }
  final view = ByteData.sublistView(bytes);
  int? rate;
  int? channels;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = ascii.decode(
      bytes.sublist(offset, offset + 4),
      allowInvalid: true,
    );
    final size = view.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      if (body + 16 > bytes.length) break;
      final format = view.getUint16(body, Endian.little);
      final bits = view.getUint16(body + 14, Endian.little);
      // 0xFFFE is WAVE_FORMAT_EXTENSIBLE, used by some encoders for PCM.
      if ((format != 1 && format != 0xFFFE) || bits != 16) {
        throw FormatException(
          'Only 16-bit PCM WAV is supported ($format/$bits).',
        );
      }
      channels = view.getUint16(body + 2, Endian.little);
      rate = view.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      if (rate == null || channels == null) {
        throw const FormatException('WAV data before its format chunk.');
      }
      final end = size == 0 || size == 0xFFFFFFFF || body + size > bytes.length
          ? bytes.length
          : body + size;
      final frame = 2 * channels;
      final usable = end - body - (end - body) % frame;
      return (
        pcm: Uint8List.sublistView(bytes, body, body + usable),
        sampleRate: rate,
        channels: channels,
      );
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV has no audio data.');
}
