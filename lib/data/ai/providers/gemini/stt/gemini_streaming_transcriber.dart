import 'package:neiroha/data/ai/protocols/gemini/gemini_live_session.dart';
import 'package:neiroha/domain/ai/ai.dart';

import '../gemini_endpoint.dart';

/// `gemini-3.5-transcribe-live`: push-to-talk transcription over Live.
/// [AudioStreamSession.finish] ends the utterance and waits for the text.
class GeminiStreamingTranscriber implements StreamingTranscriber {
  GeminiStreamingTranscriber(this.descriptor, this.endpoint);
  @override
  final ModelDescriptor descriptor;
  final GeminiEndpoint endpoint;

  @override
  Future<AudioStreamSession> open({
    TranscribeOptions options = const TranscribeOptions(),
  }) => GeminiLiveSession.connect(
    uri: endpoint.liveUri,
    mode: GeminiLiveMode.transcription,
    manualTurns: true,
    setup: geminiLiveSetup(
      model: descriptor.id,
      mode: GeminiLiveMode.transcription,
      transcribe: options,
    ),
  );
}
