import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/storage/ffmpeg_service.dart';

/// Decodes any audio or video file to PCM16 mono with FFmpeg (desktop).
class MediaPcmDecoder {
  const MediaPcmDecoder(this.ffmpeg);
  final FFmpegService ffmpeg;

  Future<Uint8List> decode(String path, {int sampleRate = 16000}) async {
    if (!await ffmpeg.isAvailable()) {
      throw StateError('FFmpeg is required to read this media file.');
    }
    final result = await Process.run(await ffmpeg.resolvePath(), [
      '-v', 'error', '-nostdin', '-i', path, //
      '-vn', '-ac', '1', '-ar', '$sampleRate', '-f', 's16le', 'pipe:1',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) {
      throw ProcessException(
        'ffmpeg',
        const [],
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return Uint8List.fromList(result.stdout as List<int>);
  }
}

/// Slice of PCM16 mono between two times, clamped to the buffer.
Uint8List slicePcm(Uint8List pcm, int sampleRate, Duration from, Duration to) {
  int index(Duration d) =>
      (d.inMicroseconds * sampleRate ~/ 1000000 * 2).clamp(0, pcm.length);
  return Uint8List.sublistView(pcm, index(from), index(to));
}
