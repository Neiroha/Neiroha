import 'package:neiroha/data/ai/protocols/gemini/gemini_live_session.dart';
import 'package:neiroha/data/ai/providers/gemini/tts/gemini_tts_adapter.dart';
import 'package:neiroha/domain/ai/ai.dart';

import '../gemini_endpoint.dart';

/// Gemini Live conversation (`gemini-3.8-live` …). Voices are the Gemini
/// TTS prebuilt voices.
class GeminiRealtimeModel implements RealtimeModel {
  GeminiRealtimeModel(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;

  @override
  List<String> get voices => GeminiTtsAdapter.kPrebuiltVoices;

  @override
  Future<RealtimeSession> connect(RealtimeConfig config) =>
      GeminiLiveSession.connect(
        uri: endpoint.liveUri,
        mode: GeminiLiveMode.conversation,
        manualTurns: !config.serverVad,
        setup: geminiLiveSetup(
          model: descriptor.id,
          mode: GeminiLiveMode.conversation,
          config: config,
        ),
      );
}
