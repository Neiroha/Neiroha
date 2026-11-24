import 'dart:typed_data';

import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';

/// How a character chat runs: an AI companion (an LLM answers, with tools
/// and a structured reply, and the character's own voice speaks it; the
/// microphone goes through STT) or a full-duplex Realtime call.
enum ChatEngine {
  companion,
  realtime;

  static ChatEngine fromName(String name) =>
      values.where((e) => e.name == name).firstOrNull ?? companion;
}

enum ConversationState { idle, connecting, listening, thinking, speaking }

sealed class ConversationEvent {
  const ConversationEvent();
}

class ConversationStateChanged extends ConversationEvent {
  const ConversationStateChanged(this.state);
  final ConversationState state;
}

/// What the user said (final transcript) or typed.
class UserTurn extends ConversationEvent {
  const UserTurn(this.text);
  final String text;
}

/// Character reply text: deltas while streaming, then [done]. A structured
/// reply also carries its [emotion] and delivery [style].
class CharacterTurn extends ConversationEvent {
  const CharacterTurn(this.text, {this.done = false, this.emotion, this.style});
  final String text;
  final bool done;
  final String? emotion;
  final String? style;
}

/// The character called a tool while answering.
class ToolUsed extends ConversationEvent {
  const ToolUsed(this.name, this.arguments, this.result);
  final String name;
  final String arguments;
  final String result;
}

class ConversationFailed extends ConversationEvent {
  const ConversationFailed(this.error);
  final Object error;
}

abstract interface class ConversationEngine {
  Stream<ConversationEvent> get events;
  Future<void> start();
  Future<void> stop();

  /// Typed input, for when the microphone is off or unavailable.
  Future<void> sendText(String text);
}

/// Microphone in, speakers out. One sink per character reply.
abstract interface class ConversationAudioIo {
  int get microphoneRate;
  Future<Stream<Uint8List>> startMicrophone();
  Future<void> stopMicrophone();
  StreamingAudioSink newSink();
  Future<void> dispose();
}
