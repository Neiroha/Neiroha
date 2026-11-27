import 'package:neiroha/data/ai/protocols/gemini/gemini_live_session.dart';
import 'package:neiroha/domain/ai/ai.dart';

import '../gemini_endpoint.dart';

/// `gemini-3.5-live-translate-preview`: speech in, translated speech out,
/// with source and target transcripts. Target codes are BCP-47 (`zh-Hans`).
class GeminiSpeechTranslator implements SpeechTranslator {
  GeminiSpeechTranslator(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;

  @override
  Future<AudioStreamSession> open({required String targetLanguage}) =>
      GeminiLiveSession.connect(
        uri: endpoint.liveUri,
        mode: GeminiLiveMode.translation,
        manualTurns: false,
        setup: geminiLiveSetup(
          model: descriptor.id,
          mode: GeminiLiveMode.translation,
          targetLanguage: targetLanguage,
        ),
      );
}
