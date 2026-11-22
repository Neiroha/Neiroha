import 'dart:typed_data';

/// Encoded audio file handed to a file-based capability (STT, VC).
class AudioInput {
  const AudioInput(
    this.bytes, {
    this.fileName = 'audio.wav',
    this.contentType = 'audio/wav',
  });
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}
