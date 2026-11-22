import 'dart:async';

import 'package:neiroha/domain/ai/events/session_events.dart';
import 'package:neiroha/domain/ai/models/capability_model.dart';

class RealtimeConfig {
  const RealtimeConfig({
    this.instructions = '',
    this.voice,
    this.audioOutput = true,
    this.transcribeInput = false,
    this.serverVad = false,
  });
  final String instructions;
  final String? voice;
  final bool audioOutput;
  final bool transcribeInput;

  /// Full duplex: the server detects turns, replies on its own and cuts its
  /// reply short when the user starts talking. Off = manual commits.
  final bool serverVad;
}

/// Full-duplex conversation. [finish] commits buffered audio and waits for the
/// model's reply; [sendText] + [respond] drive a text turn.
abstract interface class RealtimeSession implements AudioStreamSession {
  void sendText(String text);
  Future<ResponseDone> respond({Duration timeout});
  void cancelResponse();
}

abstract interface class RealtimeModel implements CapabilityModel {
  Future<RealtimeSession> connect(RealtimeConfig config);

  /// Voice names [RealtimeConfig.voice] accepts; the first is the default.
  List<String> get voices;
}
