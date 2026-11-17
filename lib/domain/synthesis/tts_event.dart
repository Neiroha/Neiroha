import 'dart:typed_data';

enum AudioEncoding { pcmS16le, mp3, wav, ogg, aac, flac }

/// PCM parameters are mandatory and validated; encoded streams self-describe.
class TtsAudioFormat {
  final AudioEncoding encoding;
  final int? sampleRate;
  final int? channels;

  const TtsAudioFormat(this.encoding, {this.sampleRate, this.channels});

  void validate() {
    if (encoding == AudioEncoding.pcmS16le &&
        ((sampleRate ?? 0) <= 0 || (channels != 1 && channels != 2))) {
      throw FormatException('PCM requires a sample rate and 1 or 2 channels.');
    }
  }

  String get extension => switch (encoding) {
    AudioEncoding.pcmS16le || AudioEncoding.wav => '.wav',
    AudioEncoding.mp3 => '.mp3',
    AudioEncoding.ogg => '.ogg',
    AudioEncoding.aac => '.aac',
    AudioEncoding.flac => '.flac',
  };

  String get contentType => switch (encoding) {
    AudioEncoding.pcmS16le || AudioEncoding.wav => 'audio/wav',
    AudioEncoding.mp3 => 'audio/mpeg',
    AudioEncoding.ogg => 'audio/ogg',
    AudioEncoding.aac => 'audio/aac',
    AudioEncoding.flac => 'audio/flac',
  };

  static TtsAudioFormat fromContentType(String type) {
    final mime = type.toLowerCase().split(';').first.trim();
    final encoding = switch (mime) {
      'audio/wav' || 'audio/x-wav' || 'audio/wave' => AudioEncoding.wav,
      'audio/ogg' || 'audio/opus' => AudioEncoding.ogg,
      'audio/aac' => AudioEncoding.aac,
      'audio/flac' || 'audio/x-flac' => AudioEncoding.flac,
      'audio/mpeg' || 'audio/mp3' => AudioEncoding.mp3,
      _ => throw FormatException('Unsupported audio content type: $type'),
    };
    return TtsAudioFormat(encoding);
  }

  static TtsAudioFormat fromFileBytes(Uint8List bytes, String type) {
    bool starts(List<int> magic) =>
        bytes.length >= magic.length &&
        List.generate(
          magic.length,
          (i) => bytes[i] == magic[i],
        ).every((v) => v);
    if (starts([82, 73, 70, 70]) &&
        bytes.length >= 12 &&
        bytes[8] == 87 &&
        bytes[9] == 65 &&
        bytes[10] == 86 &&
        bytes[11] == 69) {
      return const TtsAudioFormat(AudioEncoding.wav);
    }
    if (starts([102, 76, 97, 67])) {
      return const TtsAudioFormat(AudioEncoding.flac);
    }
    if (starts([79, 103, 103, 83])) {
      return const TtsAudioFormat(AudioEncoding.ogg);
    }
    if (starts([73, 68, 51])) return const TtsAudioFormat(AudioEncoding.mp3);
    return fromContentType(type);
  }
}

sealed class TtsEvent {
  const TtsEvent();
}

class TtsAudioStarted extends TtsEvent {
  final TtsAudioFormat format;
  const TtsAudioStarted(this.format);
}

class TtsAudioChunk extends TtsEvent {
  final Uint8List bytes;
  const TtsAudioChunk(this.bytes);
}

class TtsSynthesisCompleted extends TtsEvent {
  final Map<String, Object?> usage;
  final String? transcript;
  const TtsSynthesisCompleted({this.usage = const {}, this.transcript});
}
