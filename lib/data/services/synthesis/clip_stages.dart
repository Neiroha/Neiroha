import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:neiroha/data/ai/protocols/audio/wav_utils.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/speech_check.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// One pass over each spoken clip (a sentence, or a whole line).
sealed class ClipStage {
  const ClipStage();
}

/// A voice-conversion pass applied to every sentence.
class VoiceConversionStage extends ClipStage {
  const VoiceConversionStage(this.converter, this.targetVoice);
  final VoiceConverter converter;
  final String targetVoice;
}

/// Cuts leading / trailing silence down to [edge] and shortens pauses
/// longer than [maxPause]. Energy-based: 10 ms frames below [quietRms]
/// count as silence. A clip that is silent throughout is left as it is.
class SilenceTrimStage extends ClipStage {
  const SilenceTrimStage({
    this.maxPause = const Duration(milliseconds: 350),
    this.edge = const Duration(milliseconds: 60),
    this.quietRms = 300,
  });
  final Duration maxPause;
  final Duration edge;
  final double quietRms;

  /// PCM16 interleaved [pcm] with the silence trimmed.
  Uint8List apply(Uint8List pcm, int rate, int channels) {
    final frame = rate ~/ 100 * channels * 2;
    if (frame == 0 || pcm.length < frame) return pcm;
    final count = pcm.length ~/ frame;
    final voiced = [
      for (var f = 0; f < count; f++) _rms(pcm, f * frame, frame) >= quietRms,
    ];
    final first = voiced.indexOf(true);
    if (first < 0) return pcm;
    final last = voiced.lastIndexOf(true);
    final edgeFrames = edge.inMilliseconds ~/ 10;
    final pauseFrames = math.max(1, maxPause.inMilliseconds ~/ 10);
    final start = math.max(0, first - edgeFrames);
    final end = math.min(count, last + 1 + edgeFrames);
    final out = BytesBuilder(copy: false);
    var f = start;
    while (f < end) {
      if (voiced[f]) {
        out.add(Uint8List.sublistView(pcm, f * frame, (f + 1) * frame));
        f++;
        continue;
      }
      var g = f;
      while (g < end && !voiced[g]) {
        g++;
      }
      final gap = g - f;
      // Keep both ends of a long pause so speech does not start abruptly.
      final keep = math.min(gap, pauseFrames);
      final head = keep ~/ 2;
      out.add(Uint8List.sublistView(pcm, f * frame, (f + head) * frame));
      out.add(
        Uint8List.sublistView(pcm, (g - (keep - head)) * frame, g * frame),
      );
      f = g;
    }
    // The last partial frame stays when the clip ends in speech.
    if (end == count && pcm.length > count * frame) {
      out.add(Uint8List.sublistView(pcm, count * frame));
    }
    return out.takeBytes();
  }

  static double _rms(Uint8List bytes, int start, int length) {
    final view = ByteData.sublistView(bytes, start, start + length);
    var sum = 0.0;
    final n = length ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = view.getInt16(i * 2, Endian.little);
      sum += s * s;
    }
    return math.sqrt(sum / n);
  }
}

/// Transcribes each clip and reports what the TTS skipped. Runs beside
/// playback: the audio is never held back or changed.
class SpeechCheckStage extends ClipStage {
  const SpeechCheckStage(
    this.transcriber, {
    required this.report,
    this.language,
  });
  final Transcriber transcriber;
  final void Function(SpeechCheck check) report;
  final String? language;

  Future<void> check(
    String text,
    AudioInput audio, {
    TtsCancelToken? cancellation,
  }) async {
    try {
      final heard = await transcriber.transcribe(
        audio,
        options: TranscribeOptions(
          languages: [
            if (language case final l? when l.trim().isNotEmpty) l.trim(),
          ],
        ),
        cancellation: cancellation,
      );
      report(compareSpeech(text, heard.text));
    } on TtsCancelledException {
      // The line was stopped; nothing to report.
    } catch (error) {
      report(SpeechCheck(expected: text, heard: '', score: 0, error: error));
    }
  }

  /// [check] on PCM.
  Future<void> checkPcm(
    String text,
    Uint8List pcm,
    int rate,
    int channels, {
    TtsCancelToken? cancellation,
  }) => check(
    text,
    AudioInput(
      wrapPcmAsWav(pcm, sampleRate: rate, channels: channels),
      fileName: 'check.wav',
      contentType: 'audio/wav',
    ),
    cancellation: cancellation,
  );
}
