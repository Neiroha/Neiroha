import 'dart:async';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
import 'package:neiroha/data/ai/providers/local/rvc/rvc_client.dart';
import 'package:neiroha/domain/ai/media/audio_input.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';
import 'package:neiroha/domain/ai/models/voice_converter.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/domain/synthesis/tts_event.dart';

/// RVC checkpoint [descriptor] (or `auto`: the voice's own checkpoint).
/// `targetVoice` is a catalog voice id, optionally as `Name [id]`.
class RvcVoiceConverter implements StreamingVoiceConverter {
  RvcVoiceConverter(this.descriptor, this.client);
  @override
  final ModelDescriptor descriptor;
  final RvcClient client;

  @override
  Future<TtsResult> convert(
    AudioInput audio, {
    required String targetVoice,
    TtsCancelToken? cancellation,
  }) async {
    final target = await client.resolve(
      descriptor.id,
      targetVoice,
      cancellation: cancellation,
    );
    return client.convert(
      audio,
      model: target.model,
      voice: target.voice,
      cancellation: cancellation,
    );
  }

  @override
  Stream<TtsEvent> convertStream(
    AudioInput audio, {
    required String targetVoice,
    required TtsCancelToken cancellation,
  }) async* {
    final target = await client.resolve(
      descriptor.id,
      targetVoice,
      cancellation: cancellation,
    );
    yield* client.convertStream(
      audio,
      model: target.model,
      voice: target.voice,
      cancellation: cancellation,
    );
  }
}
