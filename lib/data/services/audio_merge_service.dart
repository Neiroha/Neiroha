import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

/// Spacing and fades applied between clips when merging a batch into one
/// file (Phase TTS "Export Merged", Novel Reader book export).
class AudioMergeOptions {
  /// Silence inserted after every clip except the last.
  final double gapSeconds;

  /// Fade at the head / tail of every clip; short values (10–50 ms) remove
  /// the clicks a hard cut between two takes produces.
  final int fadeInMs;
  final int fadeOutMs;

  const AudioMergeOptions({
    this.gapSeconds = 0,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
  });

  /// No spacing or fades: a plain concat is enough.
  bool get isPlain => gapSeconds <= 0 && fadeInMs <= 0 && fadeOutMs <= 0;
}

class AudioMergeCancelled implements Exception {
  const AudioMergeCancelled();
}

class AudioMergeException implements Exception {
  final String message;
  const AudioMergeException(this.message);

  @override
  String toString() => message;
}

/// Merges clips with gaps and fades.
///
/// Every clip is first rendered to a common PCM format (48 kHz stereo
/// s16) with its fades and trailing silence baked in, then the renders are
/// joined with the concat demuxer. Rendering per clip keeps each ffmpeg
/// command short — a single filter graph over hundreds of inputs would
/// overflow the Windows command-line limit.
class AudioMergeService {
  AudioMergeService({required Future<String> Function() resolveFfmpeg})
    : _resolveFfmpeg = resolveFfmpeg;

  final Future<String> Function() _resolveFfmpeg;

  @visibleForTesting
  static String buildClipFilter(AudioMergeOptions o, {required bool last}) {
    String sec(int ms) => (ms / 1000).toStringAsFixed(3);
    return [
      'aresample=48000',
      'aformat=sample_fmts=s16:channel_layouts=stereo',
      if (o.fadeInMs > 0) 'afade=t=in:st=0:d=${sec(o.fadeInMs)}',
      // Fade-out without knowing the clip length: fade the reversed
      // clip in. TTS sentences are short, so buffering them is cheap.
      if (o.fadeOutMs > 0) ...[
        'areverse',
        'afade=t=in:st=0:d=${sec(o.fadeOutMs)}',
        'areverse',
      ],
      if (!last && o.gapSeconds > 0)
        'apad=pad_dur=${o.gapSeconds.toStringAsFixed(3)}',
    ].join(',');
  }

  /// Merge [inputs] in order into [outputPath], encoding with
  /// [encoderArgs] (e.g. `['-c:a', 'libmp3lame', '-q:a', '2']`).
  ///
  /// [onProgress] receives 0..1. Throws [AudioMergeCancelled] when
  /// [isCancelled] turns true, [AudioMergeException] on ffmpeg failure.
  Future<void> merge({
    required List<String> inputs,
    required String outputPath,
    required AudioMergeOptions options,
    required List<String> encoderArgs,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (inputs.isEmpty) throw const AudioMergeException('Nothing to merge');
    final ffmpeg = await _resolveFfmpeg();
    final work = await Directory.systemTemp.createTemp('neiroha_merge_');
    try {
      final rendered = List<String?>.filled(inputs.length, null);
      var done = 0;
      var next = 0;
      final workers = math.min(
        (Platform.numberOfProcessors ~/ 2).clamp(1, 4),
        inputs.length,
      );
      Future<void> worker() async {
        while (next < inputs.length) {
          if (isCancelled?.call() ?? false) throw const AudioMergeCancelled();
          final i = next++;
          final out = p.join(
            work.path,
            'clip_${i.toString().padLeft(5, '0')}.wav',
          );
          final r = await Process.run(ffmpeg, [
            '-y',
            '-hide_banner',
            '-v',
            'error',
            '-i',
            inputs[i],
            '-vn',
            '-af',
            buildClipFilter(options, last: i == inputs.length - 1),
            '-c:a',
            'pcm_s16le',
            out,
          ]);
          if (r.exitCode != 0) {
            throw AudioMergeException(
              '${p.basename(inputs[i])}: ${_tail('${r.stderr}')}',
            );
          }
          rendered[i] = out;
          done++;
          onProgress?.call(done / inputs.length * 0.9);
        }
      }

      await Future.wait([for (var w = 0; w < workers; w++) worker()]);
      if (isCancelled?.call() ?? false) throw const AudioMergeCancelled();

      final list = File(p.join(work.path, 'list.txt'));
      await list.writeAsString(
        rendered
            .map(
              (f) =>
                  "file '${f!.replaceAll('\\', '/').replaceAll("'", r"'\''")}'",
            )
            .join('\n'),
        flush: true,
      );
      await File(outputPath).parent.create(recursive: true);
      final r = await Process.run(ffmpeg, [
        '-y',
        '-hide_banner',
        '-v',
        'error',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        list.path,
        ...encoderArgs,
        outputPath,
      ]);
      if (r.exitCode != 0) {
        throw AudioMergeException(_tail('${r.stderr}'));
      }
      onProgress?.call(1);
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
  }

  static String _tail(String stderr) {
    final lines = stderr
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return 'ffmpeg failed';
    return lines.sublist(math.max(0, lines.length - 3)).join(' / ');
  }
}
