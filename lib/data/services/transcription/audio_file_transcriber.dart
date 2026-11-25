import 'dart:io';
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:path/path.dart' as p;

import 'media_pcm_decoder.dart';

/// Transcribes an audio file with the routed STT model, e.g. to fill a voice
/// sample's reference text. Formats the service cannot take, and files above
/// its upload limit, are re-encoded to 16 kHz WAV first.
class AudioFileTranscriber {
  AudioFileTranscriber(this.router, {this.decoder});
  final CapabilityRouter router;
  final MediaPcmDecoder? decoder;

  static const uploadLimitBytes = 24 * 1024 * 1024;
  static const _types = {
    '.wav': 'audio/wav',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.mp4': 'audio/mp4',
    '.ogg': 'audio/ogg',
    '.flac': 'audio/flac',
    '.webm': 'audio/webm',
  };

  bool get available => router.resolve<Transcriber>(AiCapability.stt) != null;

  Future<Transcript> transcribe(
    String path, {
    TranscribeOptions options = const TranscribeOptions(),
    TtsCancelToken? cancellation,
  }) async {
    final routed = router.resolve<Transcriber>(AiCapability.stt);
    if (routed == null) {
      throw CapabilityUnavailableException(AiCapability.stt.name);
    }
    final input = await audioInputFor(path);
    cancellation?.throwIfCancelled();
    return routed.model.transcribe(
      input,
      options: options,
      cancellation: cancellation,
    );
  }

  Future<AudioInput> audioInputFor(String path) async {
    final ext = p.extension(path).toLowerCase();
    final type = _types[ext];
    final file = File(path);
    if (type != null && await file.length() <= uploadLimitBytes) {
      return AudioInput(
        await file.readAsBytes(),
        fileName: p.basename(path),
        contentType: type,
      );
    }
    final pcm = await _decoder.decode(path);
    final wav = wrapPcmAsWav(pcm, sampleRate: 16000);
    // 16 kHz mono is about 1.9 MB a minute: past ~13 minutes even the
    // re-encoded file is over the limit, and the upload would be refused.
    if (wav.length > uploadLimitBytes) {
      throw AiProviderException(
        'This audio is too long to transcribe in one request (about '
        '${pcm.length ~/ 32000 ~/ 60} min; the limit is about 13 min). '
        'Trim it to the part you need first.',
      );
    }
    return AudioInput(wav, fileName: '${p.basenameWithoutExtension(path)}.wav');
  }

  MediaPcmDecoder get _decoder =>
      decoder ?? (throw StateError('This file needs FFmpeg to transcribe.'));
}

/// PCM16 mono → WAV upload for one segment.
AudioInput wavInput(Uint8List pcm, int sampleRate, {String name = 'seg'}) =>
    AudioInput(
      wrapPcmAsWav(pcm, sampleRate: sampleRate),
      fileName: '$name.wav',
    );
