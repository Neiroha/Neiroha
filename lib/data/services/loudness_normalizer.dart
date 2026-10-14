import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

/// Target for batch loudness normalization (EBU R128 / ITU-R BS.1770).
class LoudnessTarget {
  /// Integrated loudness every clip is brought to, in LUFS.
  final double lufs;

  /// Sample-peak ceiling enforced by the limiter, in dBFS.
  final double peakCeilingDb;

  /// Upper bound on the boost applied to a single clip, so near-silent
  /// takes don't get their noise floor pumped up to speech level.
  final double maxGainDb;

  /// Clips already within this many LU of [lufs] are left untouched.
  final double toleranceLu;

  const LoudnessTarget({
    required this.lufs,
    this.peakCeilingDb = -1.5,
    this.maxGainDb = 30,
    this.toleranceLu = 0.5,
  });
}

/// Result of an ffmpeg `loudnorm` analysis pass.
class LoudnessMeasurement {
  /// Integrated loudness in LUFS. `-infinity` for digital silence.
  final double integratedLufs;

  /// True peak in dBTP.
  final double truePeakDb;

  const LoudnessMeasurement({
    required this.integratedLufs,
    required this.truePeakDb,
  });

  /// Gated integrated loudness bottoms out around -70 LUFS; anything this
  /// quiet is silence or a clip too short to gate, and boosting it would
  /// only amplify noise.
  bool get isSilent =>
      !integratedLufs.isFinite ||
      integratedLufs <= LoudnessNormalizer.silenceThresholdLufs;
}

enum LoudnessOutcomeKind { adjusted, onTarget, silent, failed }

class LoudnessOutcome {
  final LoudnessOutcomeKind kind;
  final double? appliedGainDb;
  final String? error;

  const LoudnessOutcome._(this.kind, {this.appliedGainDb, this.error});

  const LoudnessOutcome.adjusted(double gainDb)
    : this._(LoudnessOutcomeKind.adjusted, appliedGainDb: gainDb);
  const LoudnessOutcome.onTarget() : this._(LoudnessOutcomeKind.onTarget);
  const LoudnessOutcome.silent() : this._(LoudnessOutcomeKind.silent);
  const LoudnessOutcome.failed(String error)
    : this._(LoudnessOutcomeKind.failed, error: error);
}

class LoudnessException implements Exception {
  final String message;
  const LoudnessException(this.message);

  @override
  String toString() => message;
}

/// Brings generated clips to a common integrated loudness so a batch of
/// sentences plays back at an even level.
///
/// Uses a static gain per clip plus a peak limiter rather than ffmpeg's
/// `loudnorm` second pass: in linear mode `loudnorm` refuses to raise a
/// clip past its true-peak headroom, so one mouth click in a whispered line
/// would keep the whole line quiet. The limiter only shaves those
/// transients and the clip's own dynamics stay intact.
///
/// Files are rewritten in place so every reference (segment rows, timeline
/// clips, cache keys) stays valid. The first rewrite copies the original
/// into [backupDirName]; later runs always start from that pristine copy,
/// so re-targeting never stacks lossy re-encodes.
class LoudnessNormalizer {
  LoudnessNormalizer({required Future<String> Function() resolveFfmpeg})
    : _resolveFfmpeg = resolveFfmpeg;

  final Future<String> Function() _resolveFfmpeg;

  static const double silenceThresholdLufs = -60;
  static const String backupDirName = '_original_audio';

  /// Extra boost allowed on top of the raw gain to make up for what the
  /// limiter shaves off; more than this would audibly squash the clip.
  static const double _maxLimiterMakeupDb = 6;

  static String backupPathFor(String path) =>
      p.join(p.dirname(path), backupDirName, p.basename(path));

  /// Records the size + mtime of the normalized output. Some modules
  /// (Novel Reader's forced regeneration) rewrite a clip at the same path;
  /// the stamp lets us tell "our output" from "fresh audio" so a stale
  /// backup is never resurrected.
  static String _stampPathFor(String path) => '${backupPathFor(path)}.stamp';

  /// The file to analyse and process for [path]: its untouched backup when
  /// the current file is still the output of an earlier run, otherwise the
  /// file itself.
  static String sourcePathFor(String path) {
    final backup = File(backupPathFor(path));
    final stamp = File(_stampPathFor(path));
    final current = File(path);
    try {
      if (backup.existsSync() &&
          stamp.existsSync() &&
          current.existsSync() &&
          stamp.readAsStringSync().trim() == _fingerprint(current)) {
        return backup.path;
      }
    } catch (_) {}
    return path;
  }

  static String _fingerprint(File file) {
    final stat = file.statSync();
    return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
  }

  Future<LoudnessMeasurement> measure(String path, {String? preFilter}) async {
    final ffmpeg = await _resolveFfmpeg();
    final filter = [?preFilter, 'loudnorm=print_format=json'].join(',');
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-nostats',
      '-i',
      path,
      '-vn',
      '-af',
      filter,
      '-f',
      'null',
      '-',
    ]);
    final stderr = '${result.stderr}';
    if (result.exitCode != 0) {
      throw LoudnessException(_stderrTail(stderr));
    }
    final parsed = parseLoudnormJson(stderr);
    if (parsed == null) {
      throw const LoudnessException('ffmpeg loudnorm produced no report');
    }
    return parsed;
  }

  /// Rewrite [path] so its integrated loudness lands on [target].
  ///
  /// [measured] may carry a measurement of [sourcePathFor] taken earlier
  /// (e.g. by an analysis pass) to skip re-measuring.
  Future<LoudnessOutcome> normalizeFile(
    String path,
    LoudnessTarget target, {
    LoudnessMeasurement? measured,
    bool keepBackup = true,
  }) async {
    try {
      final source = sourcePathFor(path);
      final m = measured ?? await measure(source);
      if (m.isSilent) return const LoudnessOutcome.silent();

      final rawGain = (target.lufs - m.integratedLufs).clamp(
        -target.maxGainDb,
        target.maxGainDb,
      );
      // A file that was already rewritten from its backup must be redone
      // even when the original happens to sit on target — the current file
      // may hold an earlier run at a different target.
      if (source == path && rawGain.abs() <= target.toleranceLu) {
        return const LoudnessOutcome.onTarget();
      }

      var gain = rawGain.toDouble();
      final needsLimiter = m.truePeakDb + gain > target.peakCeilingDb;
      if (needsLimiter && gain > 0) {
        gain = await _compensateForLimiter(source, target, gain, rawGain);
      }

      final ffmpeg = await _resolveFfmpeg();
      final ext = p.extension(path).toLowerCase();
      final tmp = File(
        p.join(
          p.dirname(path),
          '${p.basenameWithoutExtension(path)}.loudnorm_tmp$ext',
        ),
      );
      Future<ProcessResult> render({required bool limiterLevelFlag}) {
        return Process.run(ffmpeg, [
          '-y',
          '-hide_banner',
          '-v',
          'error',
          '-i',
          source,
          '-vn',
          '-af',
          buildGainFilter(
            gain,
            target.peakCeilingDb,
            limiter: needsLimiter,
            limiterLevelFlag: limiterLevelFlag,
          ),
          ...encoderArgsFor(ext),
          tmp.path,
        ]);
      }

      var result = await render(limiterLevelFlag: true);
      // FFmpeg < 4.4 has no `level` option on alimiter (and no auto-level
      // to disable either), so retry without it.
      if (result.exitCode != 0 &&
          needsLimiter &&
          '${result.stderr}'.contains('level')) {
        result = await render(limiterLevelFlag: false);
      }
      if (result.exitCode != 0) {
        await _deleteQuietly(tmp);
        return LoudnessOutcome.failed(_stderrTail('${result.stderr}'));
      }

      final fromBackup = source != path;
      if (keepBackup && !fromBackup) {
        // Overwrites any stale backup left from audio since regenerated.
        final backup = File(backupPathFor(path));
        await backup.parent.create(recursive: true);
        await File(path).copy(backup.path);
      }
      // Copy-over rather than rename: File.copy replaces the destination on
      // every platform, so the original path keeps its identity.
      await tmp.copy(path);
      await _deleteQuietly(tmp);
      final stamp = File(_stampPathFor(path));
      if (keepBackup || fromBackup) {
        await stamp.writeAsString(_fingerprint(File(path)), flush: true);
      } else {
        await _deleteQuietly(stamp);
      }
      return LoudnessOutcome.adjusted(gain);
    } catch (e) {
      return LoudnessOutcome.failed('$e');
    }
  }

  /// The limiter pulls integrated loudness down when it has to catch many
  /// peaks; measure the processed chain and top the gain up (bounded) until
  /// the clip lands within tolerance.
  Future<double> _compensateForLimiter(
    String source,
    LoudnessTarget target,
    double gain,
    double rawGain,
  ) async {
    final maxGain = math.min(target.maxGainDb, rawGain + _maxLimiterMakeupDb);
    for (var i = 0; i < 2; i++) {
      final LoudnessMeasurement probe;
      try {
        probe = await measure(
          source,
          preFilter: buildGainFilter(gain, target.peakCeilingDb, limiter: true),
        );
      } catch (_) {
        break;
      }
      final shortfall = target.lufs - probe.integratedLufs;
      if (shortfall <= target.toleranceLu) break;
      final next = math.min(gain + shortfall, maxGain);
      if (next - gain < 0.1) break;
      gain = next;
    }
    return gain;
  }

  @visibleForTesting
  static String buildGainFilter(
    double gainDb,
    double ceilingDb, {
    required bool limiter,
    bool limiterLevelFlag = true,
  }) {
    final volume = 'volume=${gainDb.toStringAsFixed(2)}dB';
    if (!limiter) return volume;
    // alimiter accepts 0.0625..1 (−24..0 dBFS).
    final limit = math
        .pow(10, ceilingDb / 20)
        .toDouble()
        .clamp(0.0625, 1.0)
        .toStringAsFixed(4);
    final level = limiterLevelFlag ? ':level=disabled' : '';
    return '$volume,alimiter=limit=$limit:attack=5:release=50$level';
  }

  /// Encoder arguments that keep the file's container and a quality close
  /// to the TTS original.
  @visibleForTesting
  static List<String> encoderArgsFor(String ext) {
    switch (ext) {
      case '.mp3':
        return const ['-c:a', 'libmp3lame', '-q:a', '2'];
      case '.m4a':
      case '.aac':
        return const ['-c:a', 'aac', '-b:a', '192k'];
      case '.ogg':
      case '.opus':
        return const ['-c:a', 'libopus', '-b:a', '128k'];
      case '.flac':
        return const ['-c:a', 'flac'];
      case '.wav':
      default:
        return const ['-c:a', 'pcm_s16le'];
    }
  }

  /// Pull the JSON block `loudnorm=print_format=json` writes to stderr.
  @visibleForTesting
  static LoudnessMeasurement? parseLoudnormJson(String stderr) {
    final marker = stderr.lastIndexOf('Parsed_loudnorm');
    final start = stderr.indexOf('{', marker < 0 ? 0 : marker);
    if (start < 0) return null;
    final end = stderr.indexOf('}', start);
    if (end < 0) return null;
    try {
      final json = jsonDecode(stderr.substring(start, end + 1));
      if (json is! Map) return null;
      final integrated = _parseDb(json['input_i']);
      final peak = _parseDb(json['input_tp']);
      if (integrated == null || peak == null) return null;
      return LoudnessMeasurement(integratedLufs: integrated, truePeakDb: peak);
    } catch (_) {
      return null;
    }
  }

  static double? _parseDb(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is! String) return null;
    final value = raw.trim().toLowerCase();
    if (value == '-inf' || value == '-infinity') return double.negativeInfinity;
    if (value == 'inf' || value == '+inf') return double.infinity;
    return double.tryParse(value);
  }

  static String _stderrTail(String stderr) {
    final lines = const LineSplitter()
        .convert(stderr)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return 'ffmpeg failed';
    return lines.sublist(math.max(0, lines.length - 3)).join(' / ');
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
