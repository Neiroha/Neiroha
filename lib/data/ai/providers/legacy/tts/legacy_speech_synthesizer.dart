import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/speech_synthesizer.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// Bridges an existing [TtsAdapter] into [SpeechSynthesizer] without
/// changing its behaviour. M1 keeps `createAdapter` as the source of truth.
class LegacySpeechSynthesizer implements SpeechSynthesizer {
  LegacySpeechSynthesizer(this.descriptor, this.adapter);
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
