import 'dart:async';

import '../database/app_database.dart';

/// User-tunable export defaults persisted in `AppSettings`. All values
/// are codec/format identifiers passed straight to ffmpeg; the UI is
/// responsible for limiting choices to the allowlists below.
///
/// Missing settings fall back to the [defaults]; loading is
/// fault-tolerant so a corrupt setting never blocks an export.
class ExportPrefs {
  final String audioFormat; // see [audioFormats]
  final String videoCodec; // see [videoCodecs]
  final String videoAudioCodec; // see [videoAudioCodecs]

  const ExportPrefs({
    this.audioFormat = 'mp3',
    this.videoCodec = 'copy',
    this.videoAudioCodec = 'aac',
  });

  static const ExportPrefs defaults = ExportPrefs();

  /// Audio formats we know how to write directly. `wav` and `flac`
  /// avoid quality loss; `mp3` is the smallest universal choice.
  static const List<String> audioFormats = ['mp3', 'wav', 'flac'];

  /// Video encoders we expose. `copy` is special — no re-encode, fast,
  /// keeps the source's quality. The rest force a transcode and need
  /// the corresponding ffmpeg build.
  static const List<String> videoCodecs = ['copy', 'h264', 'h265', 'av1'];

  /// Audio encoders for muxed video exports.
  static const List<String> videoAudioCodecs = ['aac', 'mp3', 'opus'];

  /// File extension implied by [audioFormat]. Always lowercase, with
  /// the leading dot.
  String get audioExtension {
    switch (audioFormat) {
      case 'wav':
        return '.wav';
      case 'flac':
        return '.flac';
      case 'mp3':
      default:
        return '.mp3';
    }
  }

  /// ffmpeg `-c:a` value for the audio-only export.
  String get audioFfmpegCodec {
    switch (audioFormat) {
      case 'wav':
        return 'pcm_s16le';
      case 'flac':
        return 'flac';
      case 'mp3':
      default:
        return 'libmp3lame';
    }
  }

  /// ffmpeg `-c:v` value for the muxed video export. `copy` returns
  /// `'copy'`; named codecs map to their `lib*` encoder.
  String get videoFfmpegCodec {
    switch (videoCodec) {
      case 'h264':
        return 'libx264';
      case 'h265':
        return 'libx265';
      case 'av1':
        return 'libsvtav1';
      case 'copy':
      default:
        return 'copy';
    }
  }

  /// ffmpeg `-c:a` value for the muxed video export.
  String get videoAudioFfmpegCodec {
    switch (videoAudioCodec) {
      case 'mp3':
        return 'libmp3lame';
      case 'opus':
        return 'libopus';
      case 'aac':
      default:
        return 'aac';
    }
  }

  ExportPrefs copyWith({
    String? audioFormat,
    String? videoCodec,
    String? videoAudioCodec,
  }) => ExportPrefs(
    audioFormat: audioFormat ?? this.audioFormat,
    videoCodec: videoCodec ?? this.videoCodec,
    videoAudioCodec: videoAudioCodec ?? this.videoAudioCodec,
  );
}

/// Thin reader/writer over the settings table for [ExportPrefs].
class ExportPrefsService {
  ExportPrefsService(this._db);

  final AppDatabase _db;

  static const String kAudioFormat = 'export.audioFormat';
  static const String kVideoCodec = 'export.videoCodec';
  static const String kVideoAudioCodec = 'export.videoAudioCodec';

  Future<ExportPrefs> load() async {
    final af = await _db.getSetting(kAudioFormat);
    final vc = await _db.getSetting(kVideoCodec);
    final vac = await _db.getSetting(kVideoAudioCodec);
    return ExportPrefs(
      audioFormat: ExportPrefs.audioFormats.contains(af)
          ? af!
          : ExportPrefs.defaults.audioFormat,
      videoCodec: ExportPrefs.videoCodecs.contains(vc)
          ? vc!
          : ExportPrefs.defaults.videoCodec,
      videoAudioCodec: ExportPrefs.videoAudioCodecs.contains(vac)
          ? vac!
          : ExportPrefs.defaults.videoAudioCodec,
    );
  }

  Future<void> setAudioFormat(String v) => _db.setSetting(kAudioFormat, v);
  Future<void> setVideoCodec(String v) => _db.setSetting(kVideoCodec, v);
  Future<void> setVideoAudioCodec(String v) =>
      _db.setSetting(kVideoAudioCodec, v);
}
