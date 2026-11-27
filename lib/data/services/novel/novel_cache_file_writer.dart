import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

class NovelCacheFileWriter {
  const NovelCacheFileWriter(this.ffmpeg, this.capabilities);
  final FFmpegService ffmpeg;
  final PlatformCapabilities capabilities;
  Future<String> write({
    required TtsResult result,
    required Directory outDir,
    required String fileBase,
    required bool force,
  }) async {
    final mp3Path = p.join(outDir.path, '$fileBase.mp3');
    final mp3File = File(mp3Path);
    if (_isMp3ContentType(result.contentType)) {
      if (force || !await mp3File.exists()) {
        await mp3File.writeAsBytes(result.audioBytes, flush: true);
      }
      return mp3Path;
    }

    final sourceExt = TtsAudioFormat.fromFileBytes(
      result.audioBytes,
      result.contentType,
    ).extension;
    final tempPath = p.join(outDir.path, '.$fileBase.source$sourceExt');
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(result.audioBytes, flush: true);
      if (await _convertAudioToMp3(tempPath, mp3Path)) {
        return mp3Path;
      }
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }

    final fallbackPath = p.join(outDir.path, '$fileBase$sourceExt');
    final fallbackFile = File(fallbackPath);
    if (force || !await fallbackFile.exists()) {
      await fallbackFile.writeAsBytes(result.audioBytes, flush: true);
    }
    return fallbackPath;
  }

  Future<bool> _convertAudioToMp3(String inputPath, String outputPath) async {
    if (!capabilities.supportsLocalAudioMuxing) return false;
    if (!await ffmpeg.isAvailable()) return false;
    final ffmpegPath = await ffmpeg.resolvePath();
    try {
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-v',
        'error',
        '-i',
        inputPath,
        '-c:a',
        'libmp3lame',
        '-q:a',
        '4',
        outputPath,
      ]);
      return result.exitCode == 0 && await File(outputPath).exists();
    } catch (_) {
      return false;
    }
  }

  bool _isMp3ContentType(String contentType) {
    final lower = contentType.toLowerCase();
    return lower.contains('mpeg') || lower.contains('mp3');
  }
}
