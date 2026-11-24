import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/llm/llm_contract.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';

import 'character_live_settings.dart';
import 'character_tools.dart';
import 'companion_conversation.dart';
import 'conversation_engine.dart';
import 'realtime_conversation.dart';

/// Builds a live dialog engine for one character from whatever capabilities
/// the enabled providers offer.
class ConversationFactory {
  ConversationFactory(this.router, {this.decode, VoiceChainRunner? runner})
    : runner = runner ?? VoiceChainRunner(router);
  final CapabilityRouter router;

  /// Runs the character chain's steps (tests pass a fake).
  final VoiceChainRunner runner;

  /// Decoder for encoded TTS / VC output in the companion's sentence stream.
  final AudioDecoder? decode;

  /// Which chat engines the current providers can run.
  Set<ChatEngine> availableEngines() => {
    if (router.resolve<LanguageModel>(AiCapability.llm) != null)
      ChatEngine.companion,
    if (router.resolve<RealtimeModel>(AiCapability.realtime) != null)
      ChatEngine.realtime,
  };

  /// Whether the companion can hear the microphone (STT and VAD exist).
  bool get companionCanListen =>
      router.resolve<Transcriber>(AiCapability.stt) != null &&
      router.resolve<VoiceActivityDetector>(AiCapability.vad) != null;

  /// The character's chosen language model, or the default.
  LanguageModel? llmFor(CharacterLiveSettings settings) =>
      (settings.llmConnectionId == null
              ? null
              : router.resolve<LanguageModel>(
                  AiCapability.llm,
                  connectionId: settings.llmConnectionId,
                  modelId: settings.llmModelId,
                ))
          ?.model ??
      router.resolve<LanguageModel>(AiCapability.llm)?.model;

  /// The character's chosen Realtime model, or the default when that
  /// provider is gone or disabled.
  RoutedModel<RealtimeModel>? realtimeFor(CharacterLiveSettings settings) =>
      (settings.realtimeConnectionId == null
          ? null
          : router.resolve<RealtimeModel>(
              AiCapability.realtime,
              connectionId: settings.realtimeConnectionId,
              modelId: settings.realtimeModelId,
            )) ??
      router.resolve<RealtimeModel>(AiCapability.realtime);

  VoiceConversionStage? conversionFor(CharacterLiveSettings settings) {
    if (!settings.usesVoiceConversion) return null;
    final routed = router.resolve<VoiceConverter>(
      AiCapability.vc,
      connectionId: settings.vcConnectionId,
      modelId: settings.vcModelId,
    );
    return routed == null
        ? null
        : VoiceConversionStage(routed.model, settings.vcVoice!.trim());
  }

  String personaFor(db.VoiceAsset character, CharacterLiveSettings settings) =>
      settings.persona.trim().isNotEmpty
      ? settings.persona.trim()
      : defaultPersona(
          name: character.name,
          description: character.description,
          voiceInstruction: character.voiceInstruction,
        );

  /// The live-settings VC, unless the character's chain converts already.
  VoiceConversionStage? companionConversion(
    CharacterLiveSettings settings,
    VoiceChain chain,
  ) => chain.audioSteps.isEmpty ? conversionFor(settings) : null;

  /// The character's TTS wrapped by its chain when the chain has steps.
  TtsAdapter voiceThroughChain(TtsAdapter adapter, VoiceChain chain) =>
      chain.isActive
      ? ChainedTtsAdapter(adapter, chain, runner, decode: decode)
      : adapter;

  /// Companion replies go through the character's own processing chain
  /// ([chain]: translate / rewrite, then its VC). The live-settings VC is
  /// used only when the chain converts nothing, so speech is never
  /// converted twice.
  ///
  /// [memory] gives the character its tools and what it remembers;
  /// [history] continues a saved chat; [listen] opens the microphone.
  ConversationEngine create({
    required ChatEngine engine,
    required db.VoiceAsset character,
    required db.TtsProvider? characterProvider,
    required CharacterLiveSettings settings,
    required ConversationAudioIo io,
    VoiceChain chain = VoiceChain.empty,
    ChatMemory? memory,
    List<LlmChatMessage> history = const [],
    bool listen = true,
  }) {
    final tools = memory == null || !settings.useTools
        ? const <CharacterTool>[]
        : characterTools(memory);
    final persona = personaFor(character, settings);
    switch (engine) {
      case ChatEngine.realtime:
        final model =
            realtimeFor(settings)?.model ??
            (throw CapabilityUnavailableException(AiCapability.realtime.name));
        final remembered = memory?.prompt ?? '';
        return RealtimeConversation(
          model: model,
          io: io,
          instructions: [
            persona,
            remembered,
            _recap(history),
          ].where((s) => s.isNotEmpty).join('\n\n'),
          // A voice saved for another vendor's model would be rejected.
          voice: model.voices.contains(settings.realtimeVoice)
              ? settings.realtimeVoice
              : null,
          conversion: conversionFor(settings),
          decode: decode,
          allowInterruptions: settings.allowInterruptions,
          tools: tools,
        );
      case ChatEngine.companion:
        final hear = listen && companionCanListen;
        SpeakText voice(String style) => (text, cancellation) {
          final provider =
              characterProvider ??
              (throw StateError('${character.name} has no TTS provider.'));
          return voiceThroughChain(
            createAdapter(provider, modelName: character.modelName),
            chain,
          ).synthesizeStream(
            quickTtsRequest(
              character,
              provider,
              text,
              responseFormat: 'pcm',
              style: style,
            ),
            cancellation: cancellation,
          );
        };
        return CompanionConversation(
          vad: hear
              ? router.resolve<VoiceActivityDetector>(AiCapability.vad)?.model
              : null,
          transcriber: hear
              ? router.resolve<Transcriber>(AiCapability.stt)?.model
              : null,
          llm:
              llmFor(settings) ??
              (throw CapabilityUnavailableException(AiCapability.llm.name)),
          io: io,
          systemPrompt: persona,
          conversion: companionConversion(settings, chain),
          decode: decode,
          speak: voice(''),
          speakWith: voice,
          tools: tools,
          instructions: memory == null ? null : () => memory.prompt,
          history: history,
        );
    }
  }

  /// The end of a saved chat, for a Realtime call that picks it up again.
  static String _recap(List<LlmChatMessage> history) {
    if (history.isEmpty) return '';
    final lines = history.reversed
        .take(12)
        .toList()
        .reversed
        .map((m) => '${m.role == 'user' ? 'User' : 'You'}: ${m.content}');
    return 'The conversation so far:\n${lines.join('\n')}';
  }
}
