import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/services/transcription/audio_file_transcriber.dart';
import 'package:neiroha/data/services/transcription/media_pcm_decoder.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

import 'segment_planner.dart';
import 'subtitle_cue.dart';
import 'subtitle_translator.dart';

typedef PcmDecode = Future<Uint8List> Function(String path, int sampleRate);

enum SubtitleStage { decoding, detecting, transcribing, translating, done }

class SubtitleProgress {
  const SubtitleProgress(this.stage, [this.done = 0, this.total = 0]);
  final SubtitleStage stage;
  final int done;
  final int total;
}

class SubtitleJob {
  const SubtitleJob(
    this.mediaPath, {
    this.sourceLanguages = const [],
    this.targetLanguage,
    this.context = '',
  });
  final String mediaPath;
  final List<String> sourceLanguages;

  /// Null keeps the original language only.
  final String? targetLanguage;

  /// Optional hint for the translator (title, names, genre).
  final String context;
}

/// Media → VAD chunks → STT per chunk → optional LLM translation → cues.
/// Works with any providers that offer `vad`, `stt` and (for translation)
/// `llm`; timings come from VAD, so STT models without timestamps suffice.
class SubtitlePipeline {
  SubtitlePipeline({
    required this.decode,
    required this.vad,
    required this.transcriber,
    this.translator,
    this.sampleRate = 16000,
    this.concurrency = 3,
  });

  factory SubtitlePipeline.fromRouter(
    CapabilityRouter router,
    MediaPcmDecoder decoder, {
    bool translate = false,
  }) {
    T need<T extends CapabilityModel>(AiCapability cap) =>
        router.resolve<T>(cap)?.model ??
        (throw CapabilityUnavailableException(cap.name));
    return SubtitlePipeline(
      decode: (path, rate) => decoder.decode(path, sampleRate: rate),
      vad: need<VoiceActivityDetector>(AiCapability.vad),
      transcriber: need<Transcriber>(AiCapability.stt),
      translator: translate
          ? SubtitleTranslator(need<LanguageModel>(AiCapability.llm))
          : null,
    );
  }

  final PcmDecode decode;
  final VoiceActivityDetector vad;
  final Transcriber transcriber;
  final SubtitleTranslator? translator;
  final int sampleRate;
  final int concurrency;

  Future<List<SubtitleCue>> run(
    SubtitleJob job, {
    void Function(SubtitleProgress progress)? onProgress,
    TtsCancelToken? cancellation,
  }) async {
    void report(SubtitleStage s, [int done = 0, int total = 0]) =>
        onProgress?.call(SubtitleProgress(s, done, total));

    report(SubtitleStage.decoding);
    final pcm = await decode(job.mediaPath, sampleRate);
    cancellation?.throwIfCancelled();
    report(SubtitleStage.detecting);
    final chunks = planSubtitleChunks(
      vad.segments(pcm, sampleRate: sampleRate),
    );

    final texts = List<String>.filled(chunks.length, '');
    var next = 0;
    var finished = 0;
    report(SubtitleStage.transcribing, 0, chunks.length);
    Future<void> worker() async {
      while (next < chunks.length) {
        final i = next++;
        cancellation?.throwIfCancelled();
        final c = chunks[i];
        final transcript = await transcriber.transcribe(
          wavInput(slicePcm(pcm, sampleRate, c.start, c.end), sampleRate),
          options: TranscribeOptions(languages: job.sourceLanguages),
          cancellation: cancellation,
        );
        texts[i] = transcript.text.trim();
        report(SubtitleStage.transcribing, ++finished, chunks.length);
      }
    }

    await Future.wait([
      for (var w = 0; w < concurrency.clamp(1, 8); w++) worker(),
    ]);
    var cues = [
      for (var i = 0; i < chunks.length; i++)
        if (texts[i].isNotEmpty)
          SubtitleCue(chunks[i].start, chunks[i].end, texts[i]),
    ];

    final target = job.targetLanguage?.trim();
    if (translator != null && target != null && target.isNotEmpty) {
      report(SubtitleStage.translating, 0, cues.length);
      final lines = await translator!.translate(
        [for (final c in cues) c.text],
        targetLanguage: target,
        context: job.context,
        cancellation: cancellation,
        onProgress: (d, t) => report(SubtitleStage.translating, d, t),
      );
      cues = [
        for (var i = 0; i < cues.length; i++) cues[i].withTranslation(lines[i]),
      ];
    }
    report(SubtitleStage.done, cues.length, cues.length);
    return cues;
  }
}
