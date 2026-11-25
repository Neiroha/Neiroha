import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

abstract interface class SpeechSynthesizer implements CapabilityModel {
  Stream<TtsEvent> synthesize(
    TtsRequest request, {
    required TtsCancelToken cancellation,
  });
  Future<List<String>> voices();
}
