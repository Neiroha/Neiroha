import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

abstract interface class VoiceConverter implements CapabilityModel {
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  });
}
