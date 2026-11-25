import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/speech_synthesizer.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// Exposes a vendor-native [TtsAdapter] as a [SpeechSynthesizer] without
/// changing its behaviour.
class AdapterSpeechSynthesizer implements SpeechSynthesizer {
  AdapterSpeechSynthesizer(this.descriptor, this.adapter);
  @override
  final ModelDescriptor descriptor;
  final TtsAdapter adapter;

  @override
  Stream<TtsEvent> synthesize(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  }) => adapter.synthesizeStream(request, cancellation: cancellation);

  @override
  Future<List<String>> voices() => adapter.getSpeakers();
}
