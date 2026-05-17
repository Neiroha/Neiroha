import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';

/// Resolves the system `ffmpeg` executable. We deliberately do **not**
/// bundle ffmpeg — users bring their own to avoid the LGPL/GPL codec
/// licensing mess. If not configured + not on PATH, features that need it
/// (waveform extraction, transcoding-on-import) degrade gracefully.
///
/// Resolution order for [resolvePath]:
///  1. Explicit user override stored in `AppSettings['ffmpegPath']`.
///  2. Auto-detection via `where` (Windows) / `which` (macOS/Linux).
///  3. The literal string `ffmpeg` — the caller's Process.run can still
///     find it if the current process's PATH contains it.
class FFmpegService {
  FFmpegService(this._db, {PlatformCapabilities? capabilities})
    : _capabilities = capabilities ?? PlatformCapabilities.current();

  static const String kFfmpegPathKey = 'ffmpegPath';

  final AppDatabase _db;
  final PlatformCapabilities _capabilities;

  /// Cache the last successful probe so repeated callers don't spin up a
  /// `ffmpeg -version` child for every waveform extraction.
  String? _cachedPath;
  bool? _cachedAvailable;

  void _invalidateCache() {
    _cachedPath = null;
    _cachedAvailable = null;
  }

  /// Persist (or clear) the user's ffmpeg path override.
  Future<void> setOverride(String? absolutePath) async {
    final trimmed = absolutePath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _db.deleteSetting(kFfmpegPathKey);
    } else {
      await _db.setSetting(kFfmpegPathKey, trimmed);
    }
    _invalidateCache();
  }

  Future<String?> getOverride() => _db.getSetting(kFfmpegPathKey);

  /// Resolve the ffmpeg executable path. Falls back to the literal
  /// `ffmpeg` if nothing more specific is found.
  Future<String> resolvePath() async {
    if (!_capabilities.supportsFfmpegCli) {
      throw UnsupportedError(
        'FFmpeg CLI is not available on ${_capabilities.platformLabel}.',
      );
    }
    if (_cachedPath != null) return _cachedPath!;
    final override = await getOverride();
    if (override != null && override.isNotEmpty) {
      _cachedPath = override;
      return override;
    }
    final autod = await _whichFfmpeg();
    _cachedPath = autod ?? 'ffmpeg';
    return _cachedPath!;
  }

  /// Probe `ffmpeg -version`. `true` if exit 0. Cached per-run.
  Future<bool> isAvailable() async {
    if (!_capabilities.supportsFfmpegCli) {
      _cachedAvailable = false;
      return false;
    }
    if (_cachedAvailable != null) return _cachedAvailable!;
    final path = await resolvePath();
    try {
      final result = await Process.run(path, const ['-version']);
      _cachedAvailable = result.exitCode == 0;
    } catch (_) {
      _cachedAvailable = false;
    }
    return _cachedAvailable!;
  }

  /// Force a re-probe on the next [isAvailable] / [resolvePath] call.
  /// Call after the user changes the override path in Settings.
  void invalidate() => _invalidateCache();

  static Future<String?> _whichFfmpeg() async {
    try {
      final which = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(which, const ['ffmpeg']);
      if (result.exitCode != 0) return null;
      final stdout = (result.stdout as String).trim();
      if (stdout.isEmpty) return null;
      // `where` returns one per line on Windows; take the first.
      final first = stdout.split(RegExp(r'[\r\n]+')).first.trim();
      return first.isEmpty ? null : first;
    } catch (_) {
      return null;
    }
  }

  /// List Windows DirectShow audio capture devices via ffmpeg.
  ///
  /// FFmpeg writes the device list to stderr and exits non-zero because
  /// `dummy` is not a real input. That is expected; callers should treat an
  /// empty list as "fall back to default capture device" rather than a hard
  /// failure.
  Future<List<DshowAudioInput>> listDshowAudioInputs() async {
    if (!_capabilities.supportsFfmpegCli) return const [];
    if (!Platform.isWindows) return const [];
    if (!await isAvailable()) return const [];
    final ffmpegPath = await resolvePath();
    try {
      final result = await Process.run(ffmpegPath, const [
        '-hide_banner',
        '-list_devices',
        'true',
        '-f',
        'dshow',
        '-i',
        'dummy',
      ]).timeout(const Duration(seconds: 5));
      return parseDshowAudioInputs('${result.stderr}\n${result.stdout}');
    } catch (_) {
      return const [];
    }
  }

  @visibleForTesting
  static List<DshowAudioInput> parseDshowAudioInputs(String output) {
    final devices = <DshowAudioInput>[];
    final seen = <String>{};
    int? currentDeviceIndex;

    final deviceRe = RegExp(r'^\[dshow[^\]]*\]\s+"(.+)"\s+\(audio\)\s*$');
    final nonAudioDeviceRe = RegExp(
      r'^\[dshow[^\]]*\]\s+".+"\s+\((video|none)\)\s*$',
    );
    final altRe = RegExp(r'^\[dshow[^\]]*\]\s+Alternative name\s+"(.+)"\s*$');

    for (final line in output.split(RegExp(r'\r?\n'))) {
      final deviceMatch = deviceRe.firstMatch(line);
      if (deviceMatch != null) {
        final name = deviceMatch.group(1)!.trim();
        if (name.isEmpty || !seen.add(name)) {
          currentDeviceIndex = null;
          continue;
        }
        devices.add(DshowAudioInput(name: name));
        currentDeviceIndex = devices.length - 1;
        continue;
      }

      if (nonAudioDeviceRe.hasMatch(line)) {
        currentDeviceIndex = null;
        continue;
      }

      final altMatch = altRe.firstMatch(line);
      if (altMatch != null && currentDeviceIndex != null) {
        final alt = altMatch.group(1)!.trim();
        if (alt.isNotEmpty) {
          final current = devices[currentDeviceIndex];
          devices[currentDeviceIndex] = DshowAudioInput(
            name: current.name,
            alternativeName: alt,
          );
        }
      }
    }

    return devices;
  }

  /// Extract a mono PCM16 stream from [mediaPath] and reduce it to a
  /// normalised list of peak magnitudes (length == [bucketCount]).
  ///
  /// Streams the PCM output so memory stays flat regardless of media
  /// length — a 4-hour video would be ~230 MB if buffered whole.
  ///
  /// Returns `null` if ffmpeg/ffprobe is unavailable or the process fails
  /// — caller is responsible for rendering a placeholder + nudging the
  /// user toward the FFmpeg settings pane.
  Future<List<double>?> extractWaveformPeaks(
    String mediaPath, {
    int bucketCount = 600,
    int sampleRate = 8000,
  }) async {
    if (!_capabilities.supportsFfmpegCli) return null;
    if (!await isAvailable()) return null;
    final path = await resolvePath();

    // Sample count is needed up front to size buckets. ffprobe ships
    // alongside ffmpeg in every mainstream distro.
    final durationSec = await probeDurationSeconds(mediaPath);
    if (durationSec == null || durationSec <= 0) return null;
    final expectedSampleCount = (durationSec * sampleRate).round();
    if (expectedSampleCount < 2 || bucketCount <= 0) return null;

    Process? process;
    try {
      process = await Process.start(path, [
        '-v',
        'error',
        '-i',
        mediaPath,
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        '-',
      ]);
      // Drain stderr so a full pipe can't stall the decode.
      unawaited(process.stderr.drain<void>());

      final reducer = PeakReducer(expectedSampleCount, bucketCount);
      await for (final chunk in process.stdout) {
        reducer.addBytes(chunk);
      }
      final exit = await process.exitCode;
      if (exit != 0) return null;
      return reducer.finish();
    } catch (_) {
      process?.kill();
      return null;
    }
  }

  /// Probe media duration (seconds) via `ffprobe`. Returns `null` if
  /// ffprobe is missing or the probe fails. Images report 0 — callers
  /// should substitute a sensible default (e.g. 3 s still frame).
  Future<double?> probeDurationSeconds(String mediaPath) async {
    if (!_capabilities.supportsFfmpegCli) return null;
    final ffmpegPath = await resolvePath();
    final ffprobePath = _deriveFfprobePath(ffmpegPath);
    try {
      final result = await Process.run(ffprobePath, [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        mediaPath,
      ]);
      if (result.exitCode != 0) return null;
      final raw = (result.stdout as String).trim();
      return double.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Concatenate [inputPaths] into a single audio file at [outputPath].
  ///
  /// Uses ffmpeg's concat demuxer with a temporary listing file (the only
  /// way to safely concat files containing single quotes or non-ASCII
  /// characters on Windows). When all inputs share the same codec the
  /// stream-copy path is taken (`-c copy`), which is essentially instant;
  /// otherwise we re-encode to a sensible default for the target extension
  /// so mismatched bitrates / codecs still produce a playable file.
  ///
  /// Returns `true` on success. The temporary listing file is always
  /// removed, even on failure.
  Future<bool> concatAudio({
    required List<String> inputPaths,
    required String outputPath,
    bool reEncode = false,
  }) async {
    if (!_capabilities.supportsFfmpegCli) return false;
    if (inputPaths.isEmpty) return false;
    if (!await isAvailable()) return false;
    final ffmpegPath = await resolvePath();

    final outFile = File(outputPath);
    final outDir = outFile.parent;
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final listFile = File(
      p.join(
        outDir.path,
        '.concat_${DateTime.now().microsecondsSinceEpoch}.txt',
      ),
    );

    try {
      final buffer = StringBuffer();
      for (final raw in inputPaths) {
        // ffmpeg concat demuxer: backslashes must be forward slashes,
        // and single quotes inside the filename need escaping as `'\''`.
        final normalized = raw.replaceAll('\\', '/').replaceAll("'", r"'\''");
        buffer.writeln("file '$normalized'");
      }
      await listFile.writeAsString(buffer.toString(), flush: true);

      final ext = p.extension(outputPath).toLowerCase();
      final args = <String>[
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        if (reEncode) ...[
          '-c:a',
          _audioCodecForExt(ext),
        ] else ...[
          '-c',
          'copy',
        ],
        outputPath,
      ];

      final result = await Process.run(ffmpegPath, args);
      if (result.exitCode == 0) return true;

      // Common failure: stream-copy across mismatched codecs/sample-rates.
      // Retry once with re-encoding before giving up.
      if (!reEncode) {
        return concatAudio(
          inputPaths: inputPaths,
          outputPath: outputPath,
          reEncode: true,
        );
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      try {
        if (await listFile.exists()) await listFile.delete();
      } catch (_) {}
    }
  }

  /// Cut [inputPath] from [startSec] to [endSec] into [outputPath]. Output
  /// extension determines the container; same-codec sources stream-copy in
  /// near-instant, mismatched codecs re-encode automatically.
  ///
  /// Returns `true` on success. Caller must guarantee `endSec > startSec >=
  /// 0`. Output directory is created if missing.
  Future<bool> trimAudio({
    required String inputPath,
    required String outputPath,
    required double startSec,
    required double endSec,
  }) async {
    if (!_capabilities.supportsFfmpegCli) return false;
    if (endSec <= startSec || startSec < 0) return false;
    if (!await isAvailable()) return false;
    final ffmpegPath = await resolvePath();

    final outFile = File(outputPath);
    final outDir = outFile.parent;
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final ext = p.extension(outputPath).toLowerCase();
    // Stream-copy first; if the codec/container can't accept a copy at these
    // timestamps (common with mp3 frame boundaries), retry with re-encode.
    final copyArgs = <String>[
      '-y',
      '-ss',
      _fmtTime(startSec),
      '-to',
      _fmtTime(endSec),
      '-i',
      inputPath,
      '-c',
      'copy',
      outputPath,
    ];
    final copy = await Process.run(ffmpegPath, copyArgs);
    if (copy.exitCode == 0) return true;

    final reArgs = <String>[
      '-y',
      '-ss',
      _fmtTime(startSec),
      '-to',
      _fmtTime(endSec),
      '-i',
      inputPath,
      '-c:a',
      _audioCodecForExt(ext),
      outputPath,
    ];
    final re = await Process.run(ffmpegPath, reArgs);
    return re.exitCode == 0;
  }

  /// Format seconds as `HH:MM:SS.mmm` for ffmpeg `-ss` / `-to` flags.
  static String _fmtTime(double sec) {
    final ms = (sec * 1000).round();
    final h = ms ~/ 3600000;
    final m = (ms ~/ 60000) % 60;
    final s = (ms ~/ 1000) % 60;
    final r = ms % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${r.toString().padLeft(3, '0')}';
  }

  static String _audioCodecForExt(String ext) {
    switch (ext) {
      case '.mp3':
        return 'libmp3lame';
      case '.m4a':
      case '.aac':
        return 'aac';
      case '.ogg':
      case '.opus':
        return 'libopus';
      case '.flac':
        return 'flac';
      case '.wav':
      default:
        return 'pcm_s16le';
    }
  }

  static String _deriveFfprobePath(String ffmpegPath) {
    if (ffmpegPath == 'ffmpeg') return 'ffprobe';
    final dir = p.dirname(ffmpegPath);
    final ext = Platform.isWindows ? '.exe' : '';
    return p.join(dir, 'ffprobe$ext');
  }

  /// Legacy whole-buffer reducer kept for unit tests. Production paths
  /// should stream via [PeakReducer] to keep memory flat.
  @visibleForTesting
  static List<double> reduceToPeaks(List<int> pcm, int bucketCount) {
    final sampleCount = pcm.length ~/ 2;
    if (sampleCount == 0 || bucketCount <= 0) return const [];
    final reducer = PeakReducer(sampleCount, bucketCount);
    reducer.addBytes(pcm);
    return reducer.finish();
  }
}

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
