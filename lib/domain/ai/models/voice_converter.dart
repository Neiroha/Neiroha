import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';
import 'package:neiroha/domain/synthesis/tts_request.dart';

abstract interface class VoiceConverter implements CapabilityModel {
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  });
}

/// A converter that starts returning audio before the whole clip is
/// converted. Input is still one complete clip; output is streamed PCM.
abstract interface class StreamingVoiceConverter implements VoiceConverter {
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  });
}

/// Streams [audio] through [converter], falling back to one whole chunk for
/// converters without a streaming endpoint.
Stream<TtsEvent> convertAsStream(
  VoiceConverter converter,
  AudioInput audio, {
  required String targetVoice,
  required TtsCancelToken cancellation,
}) async* {
  if (converter is StreamingVoiceConverter) {
    yield* converter.convertStream(
      audio,
      targetVoice: targetVoice,
      cancellation: cancellation,
    );
    return;
  }
  final result = await converter.convert(
    audio,
    targetVoice: targetVoice,
    cancellation: cancellation,
  );
  cancellation.throwIfCancelled();
  yield TtsAudioStarted(
    TtsAudioFormat.fromFileBytes(result.audioBytes, result.contentType),
  );
  yield TtsAudioChunk(result.audioBytes);
  yield const TtsSynthesisCompleted();
}
