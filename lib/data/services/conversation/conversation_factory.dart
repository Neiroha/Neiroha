import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/data/services/synthesis/sentence_speech_pipeline.dart';
import 'package:neiroha/domain/ai/ai.dart';

import 'character_live_settings.dart';
import 'companion_conversation.dart';
import 'conversation_engine.dart';
import 'realtime_conversation.dart';

/// Builds a live dialog engine for one character from whatever capabilities
/// the enabled providers offer.
class ConversationFactory {
  const ConversationFactory(this.router, {this.decode});
  final CapabilityRouter router;

  /// Decoder for encoded TTS / VC output in the companion's sentence stream.
  final AudioDecoder? decode;

  T _need<T extends CapabilityModel>(AiCapability cap) =>
      router.resolve<T>(cap)?.model ??
      (throw CapabilityUnavailableException(cap.name));

  /// Which live modes the current providers can run.
  Set<DialogMode> availableModes() => {
    DialogMode.script,
    if (router.resolve<RealtimeModel>(AiCapability.realtime) != null)
      DialogMode.realtime,
    if (router.resolve<Transcriber>(AiCapability.stt) != null &&
        router.resolve<LanguageModel>(AiCapability.llm) != null &&
        router.resolve<VoiceActivityDetector>(AiCapability.vad) != null)
      DialogMode.companion,
  };

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

  ConversationEngine create({
    required DialogMode mode,
    required db.VoiceAsset character,
    required db.TtsProvider? characterProvider,
    required CharacterLiveSettings settings,
    required ConversationAudioIo io,
  }) => switch (mode) {
    DialogMode.realtime => () {
      final model =
          realtimeFor(settings)?.model ??
          (throw CapabilityUnavailableException(AiCapability.realtime.name));
      return RealtimeConversation(
        model: model,
        io: io,
        instructions: personaFor(character, settings),
        // A voice saved for another vendor's model would be rejected.
        voice: model.voices.contains(settings.realtimeVoice)
            ? settings.realtimeVoice
            : null,
        conversion: conversionFor(settings),
        allowInterruptions: settings.allowInterruptions,
      );
    }(),
    DialogMode.companion => CompanionConversation(
      vad: _need<VoiceActivityDetector>(AiCapability.vad),
      transcriber: _need<Transcriber>(AiCapability.stt),
      llm: _need<LanguageModel>(AiCapability.llm),
      io: io,
      systemPrompt: personaFor(character, settings),
      conversion: conversionFor(settings),
      decode: decode,
      speak: (text, cancellation) {
        final provider =
            characterProvider ??
            (throw StateError('${character.name} has no TTS provider.'));
        return createAdapter(
          provider,
          modelName: character.modelName,
        ).synthesizeStream(
          quickTtsRequest(character, provider, text, responseFormat: 'pcm'),
          cancellation: cancellation,
        );
      },
    ),
    DialogMode.script => throw ArgumentError('Script mode has no engine.'),
  };
}
