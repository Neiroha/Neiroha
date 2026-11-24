import 'dart:convert';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/sentence_chunker.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

import 'sentence_speech_pipeline.dart';

/// Runs the steps of a [VoiceChain] with models from a [CapabilityRouter].
class VoiceChainRunner {
  const VoiceChainRunner(this.router);
  final CapabilityRouter router;

  static String translatePrompt(String language) =>
      'Translate the user message into $language. Keep the meaning, tone, '
      'names and any bracketed or parenthesised performance tags. Reply with '
      'the translation only, without quotes or notes.';

  static String rewritePrompt(String instruction) =>
      '$instruction\nApply this to the user message. Reply with the '
      'rewritten text only, without quotes or notes.';

  T _resolve<T extends CapabilityModel>(AiCapability cap, VoiceChainStep s) {
    final routed =
        router.resolve<T>(
          cap,
          connectionId: s.connectionId,
          modelId: s.modelId,
        ) ??
        (s.connectionId == null ? null : router.resolve<T>(cap));
    if (routed == null) throw CapabilityUnavailableException(cap.name);
    return routed.model;
  }

  LanguageModel languageModel(VoiceChainStep step) =>
      _resolve<LanguageModel>(AiCapability.llm, step);

  VoiceConverter converter(VoiceChainStep step) =>
      _resolve<VoiceConverter>(AiCapability.vc, step);

  /// The line after every text step, in order.
  Future<String> prepareText(
    String text,
    VoiceChain chain, {
    TtsCancelToken? cancellation,
  }) async {
    var line = text;
    for (final step in chain.textSteps) {
      final out = await languageModel(
        step,
      ).complete(_messages(step, line), cancellation: cancellation);
      if (out.trim().isNotEmpty) line = out.trim();
    }
    return line;
  }

  /// The line after every text step as streamed deltas: earlier steps run
  /// whole (each needs the previous result), the last one streams. An empty
  /// answer keeps the original line, as [prepareText] does.
  Stream<String> streamText(
    String text,
    VoiceChain chain, {
    required TtsCancelToken cancellation,
  }) async* {
    final steps = chain.textSteps;
    if (steps.isEmpty) {
      yield text;
      return;
    }
    final head = await prepareText(
      text,
      VoiceChain(steps.sublist(0, steps.length - 1)),
      cancellation: cancellation,
    );
    final last = steps.last;
    final deltas = streamCompletion(
      languageModel(last),
      _messages(last, head),
      cancellation: cancellation,
    );
    var said = false;
    var leading = true;
    await for (final delta in deltas) {
      // Drop leading whitespace so "  Hello" does not count as speech.
      final piece = leading ? delta.trimLeft() : delta;
      if (piece.isEmpty) continue;
      leading = false;
      said = true;
      yield piece;
    }
    if (!said) yield head;
  }

  List<LlmChatMessage> _messages(VoiceChainStep step, String line) => [
    LlmChatMessage(
      role: 'system',
      content: step.kind == VoiceChainStepKind.translate
          ? translatePrompt(step.targetLanguage.trim())
          : rewritePrompt(step.instruction.trim()),
    ),
    LlmChatMessage(role: 'user', content: line),
  ];

  /// Every conversion step as a pipeline stage.
  List<VoiceConversionStage> conversionStages(VoiceChain chain) => [
    for (final step in chain.audioSteps)
      VoiceConversionStage(converter(step), step.targetVoice.trim()),
  ];

  /// The audio after every conversion step, in order.
  Future<TtsResult> convertAudio(
    TtsResult audio,
    VoiceChain chain, {
    TtsCancelToken? cancellation,
  }) async {
    var current = audio;
    for (final step in chain.audioSteps) {
      final vc = converter(step);
      final format = TtsAudioFormat.fromFileBytes(
        current.audioBytes,
        current.contentType,
      );
      current = await vc.convert(
        AudioInput(
          current.audioBytes,
          fileName: 'speech${format.extension}',
          contentType: format.contentType,
        ),
        targetVoice: step.targetVoice.trim(),
        cancellation: cancellation,
      );
    }
    return current;
  }
}

/// A TTS adapter wrapped by a chain.
///
/// With any active step the line is spoken sentence by sentence through a
/// [SentenceSpeechPipeline]: the last LLM step streams its answer, each
/// finished sentence goes to TTS, each spoken sentence through VC, and the
/// first sentence plays while the rest are still being generated. Without
/// steps the inner adapter is used untouched.
class ChainedTtsAdapter extends TtsAdapter {
  ChainedTtsAdapter(
    this.inner,
    this.chain,
    this.runner, {
    this.lookahead = 1,
    this.decode,
  });
  final TtsAdapter inner;
  final VoiceChain chain;
  final VoiceChainRunner runner;
  final int lookahead;
  final AudioDecoder? decode;

  bool get _pipelined => chain.isActive;

  @override
  get serviceRoute => inner.serviceRoute;

  /// The pipeline always delivers PCM before the line is complete.
  @override
  bool get supportsStreaming => _pipelined || inner.supportsStreaming;

  /// Upstream streaming capability only (recorded per TTS model), so a
  /// pipelined line never marks a file-only engine as streaming.
  @override
  bool streamsAudioFor(TtsRequest request) =>
      !_pipelined && inner.streamsAudioFor(request);

  Future<TtsRequest> _prepared(TtsRequest r, TtsCancelToken? c) async =>
      r.withText(await runner.prepareText(r.text, chain, cancellation: c));

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final spoken = await inner.synthesize(await _prepared(request, null));
    return runner.convertAudio(spoken, chain);
  }

  /// One sentence from the inner adapter: streamed PCM when it streams,
  /// otherwise a whole WAV file the pipeline unpacks.
  Stream<TtsEvent> _speak(
    TtsRequest request,
    String sentence,
    TtsCancelToken cancellation,
  ) {
    final pcm = request.withText(sentence).withFormat('pcm');
    return inner.synthesizeStream(
      inner.streamsAudioFor(pcm) ? pcm : pcm.withFormat('wav'),
      cancellation: cancellation,
    );
  }

  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    if (!_pipelined) {
      yield* inner.synthesizeStream(request, cancellation: cancellation);
      return;
    }
    final stages = runner.conversionStages(chain);
    if (!canConvertPerSentence(stages, decode)) {
      yield* _wholeLine(request, cancellation);
      return;
    }
    final sentences = chain.textSteps.isEmpty
        ? Stream.fromIterable(splitSentences(request.text))
        : chunkSentences(
            runner.streamText(request.text, chain, cancellation: cancellation),
          );
    var emitted = false;
    try {
      await for (final event in SentenceSpeechPipeline(
        speak: (sentence, c) => _speak(request, sentence, c),
        conversions: stages,
        lookahead: lookahead,
        decode: decode,
      ).run(sentences, cancellation: cancellation)) {
        emitted = true;
        yield event;
      }
    } on UndecodableAudioException {
      // Encoded-only engine without a decoder (web, no FFmpeg): speak the
      // whole line as before, one file, still correct, just later.
      if (emitted) rethrow;
      yield* _wholeLine(request, cancellation);
    }
  }

  Stream<TtsEvent> _wholeLine(
    TtsRequest request,
    TtsCancelToken cancellation,
  ) async* {
    final prepared = await _prepared(request, cancellation);
    cancellation.throwIfCancelled();
    final spoken = await inner.synthesize(prepared.asWholeFile());
    cancellation.throwIfCancelled();
    final result = await runner.convertAudio(
      spoken,
      chain,
      cancellation: cancellation,
    );
    cancellation.throwIfCancelled();
    yield TtsAudioStarted(
      TtsAudioFormat.fromFileBytes(result.audioBytes, result.contentType),
    );
    yield TtsAudioChunk(result.audioBytes);
    yield const TtsSynthesisCompleted();
  }

  @override
  Future<bool> healthCheck() => inner.healthCheck();
  @override
  Future<List<String>> getSpeakers() => inner.getSpeakers();
  @override
  Future<List<ModelInfo>> getModels() => inner.getModels();
}

/// Loads a character's chain from app settings and wraps its adapter.
/// Installed on the TTS queue so every app synthesis path honours it.
class VoiceChainHook {
  VoiceChainHook(this.database, {this.decode});
  final db.AppDatabase database;

  /// Lets sentence streaming read encoded engines (FFmpeg on desktop).
  final AudioDecoder? decode;

  static Future<VoiceChain> load(
    db.AppDatabase database,
    String assetId,
  ) async {
    final raw = await database.getSetting(VoiceChain.key(assetId));
    if (raw == null || raw.isEmpty) return VoiceChain.empty;
    try {
      return VoiceChain.fromJson(jsonDecode(raw));
    } on FormatException {
      return VoiceChain.empty;
    }
  }

  static Future<void> save(
    db.AppDatabase database,
    String assetId,
    VoiceChain chain,
  ) => database.setSetting(
    VoiceChain.key(assetId),
    jsonEncode(chain.normalized().toJson()),
  );

  Future<TtsAdapter> wrap(TtsAdapter adapter, TtsRequest request) async {
    final id = request.voiceAssetId;
    if (id == null) return adapter;
    final chain = await load(database, id);
    if (!chain.isActive) return adapter;
    final router = CapabilityRouter.fromProviders(
      await database.getAllProviders(),
    );
    return ChainedTtsAdapter(
      adapter,
      chain,
      VoiceChainRunner(router),
      decode: decode,
    );
  }
}
