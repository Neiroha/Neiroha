import 'dart:convert';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

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
      final model = languageModel(step);
      final system = step.kind == VoiceChainStepKind.translate
          ? translatePrompt(step.targetLanguage.trim())
          : rewritePrompt(step.instruction.trim());
      final out = await model.complete([
        LlmChatMessage(role: 'system', content: system),
        LlmChatMessage(role: 'user', content: line),
      ], cancellation: cancellation);
      if (out.trim().isNotEmpty) line = out.trim();
    }
    return line;
  }

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

/// A TTS adapter wrapped by a chain. Without audio steps the inner adapter
/// still streams; with them the line is synthesized whole, converted, then
/// delivered as one chunk.
class ChainedTtsAdapter extends TtsAdapter {
  ChainedTtsAdapter(this.inner, this.chain, this.runner);
  final TtsAdapter inner;
  final VoiceChain chain;
  final VoiceChainRunner runner;

  bool get _converts => chain.audioSteps.isNotEmpty;

  @override
  get serviceRoute => inner.serviceRoute;
  @override
  bool get supportsStreaming => !_converts && inner.supportsStreaming;
  @override
  bool streamsAudioFor(TtsRequest request) =>
      !_converts && inner.streamsAudioFor(request);

  Future<TtsRequest> _prepared(TtsRequest r, TtsCancelToken? c) async =>
      r.withText(await runner.prepareText(r.text, chain, cancellation: c));

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final spoken = await inner.synthesize(await _prepared(request, null));
    return runner.convertAudio(spoken, chain);
  }

  @override
  Stream<TtsEvent> synthesizeStream(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) async* {
    final prepared = await _prepared(request, cancellation);
    cancellation.throwIfCancelled();
    if (!_converts) {
      yield* inner.synthesizeStream(prepared, cancellation: cancellation);
      return;
    }
    // Conversion needs a whole file: never ask the inner adapter for PCM.
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
  VoiceChainHook(this.database);
  final db.AppDatabase database;

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
    return ChainedTtsAdapter(adapter, chain, VoiceChainRunner(router));
  }
}
