import 'dart:async';

import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/media/transcript.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';

/// Whole-file transcription.
abstract interface class Transcriber implements CapabilityModel {
  Future<Transcript> transcribe(
    AudioInput audio, {
    TranscribeOptions options,
    TtsCancelToken? cancellation,
  });
}

abstract interface class StreamingTranscriber implements CapabilityModel {
  Future<AudioStreamSession> open({TranscribeOptions options});
}
