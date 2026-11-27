import 'dart:typed_data';

import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// A song request. Style, structure and lyrics are prose: section tags such
/// as `[Verse]` / `[Chorus]` in [lyrics] guide the arrangement.
class MusicRequest {
  const MusicRequest({
    required this.prompt,
    this.lyrics = '',
    this.instrumental = false,
    this.images = const [],
    this.lossless = true,
  });

  /// Genre, mood, instruments, vocalist, tempo, length…
  final String prompt;

  /// Lyrics to sing; empty lets the model write its own.
  final String lyrics;
  final bool instrumental;

  /// Reference images (`(bytes, mimeType)`) for models that accept them.
  final List<(Uint8List, String)> images;

  /// Ask for WAV where the model offers it; MP3 otherwise.
  final bool lossless;
}

/// One sung line, timed when the model reports timings.
class LyricLine {
  const LyricLine(this.text, {this.start, this.end, this.section});
  final String text;
  final Duration? start;
  final Duration? end;

  /// Section label the line belongs to (`A0`, `Chorus`…), if any.
  final String? section;
}

class GeneratedSong {
  const GeneratedSong({
    required this.audio,
    required this.mimeType,
    this.lyrics = const [],
    this.rawLyrics = '',
    this.usage = const {},
  });
  final Uint8List audio;
  final String mimeType;
  final List<LyricLine> lyrics;
  final String rawLyrics;
  final Map<String, Object?> usage;

  String get extension => switch (mimeType) {
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => '.wav',
    'audio/ogg' => '.ogg',
    'audio/flac' => '.flac',
    _ => '.mp3',
  };

  bool get timed => lyrics.any((l) => l.start != null);
}

/// Text (and image) to a finished song with vocals or an instrumental.
abstract interface class MusicGenerator implements CapabilityModel {
  Future<GeneratedSong> compose(
    MusicRequest request, {
    TtsCancelToken? cancellation,
  });
}
