import 'dart:async';
import 'dart:typed_data';

import 'package:neiroha/domain/ai/events/session_events.dart';
import 'package:neiroha/domain/ai/model_descriptor.dart';

/// A model bound to a connection, ready to call for one capability.
abstract interface class CapabilityModel {
  ModelDescriptor get descriptor;
}

/// A live audio session: push PCM16 mono, read events, then finish.
abstract interface class AudioStreamSession {
  /// Sample rate [sendPcm] expects.
  int get inputSampleRate;
  Stream<AiSessionEvent> get events;
  void sendPcm(Uint8List pcm16);

  /// Flushes pending input and completes after the final output event.
  Future<void> finish({Duration timeout});
  Future<void> close();
}
