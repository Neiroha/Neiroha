import 'package:neiroha/domain/llm/tool_chat.dart';
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
    this.tools = const [],
  });
  final String instructions;

  /// Functions the model may call ([ToolCallingRealtimeSession] only).
  final List<LlmTool> tools;
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

/// A Realtime session that can call functions and be told how much of a
/// reply the user actually heard.
abstract interface class ToolCallingRealtimeSession implements RealtimeSession {
  /// Hands back a function's result and lets the model continue.
  void sendToolResult(String callId, String output);

  /// Cuts reply [itemId] at [audioEndMs], what was played before the user
  /// spoke over it, so the model knows what was heard.
  void truncate(String itemId, int audioEndMs);
}

abstract interface class RealtimeModel implements CapabilityModel {
  Future<RealtimeSession> connect(RealtimeConfig config);

  /// Voice names [RealtimeConfig.voice] accepts; the first is the default.
  List<String> get voices;
}
