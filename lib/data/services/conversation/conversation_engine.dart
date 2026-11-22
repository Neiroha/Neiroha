import 'dart:typed_data';

import 'package:neiroha/domain/synthesis/streaming_audio_sink.dart';

/// Character dialog modes: the classic script editor, a full-duplex Realtime
/// model, or a cascaded ASR → LLM → TTS companion using the character voice.
enum DialogMode { script, realtime, companion }

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

/// Character reply text: deltas while streaming, then [done].
class CharacterTurn extends ConversationEvent {
  const CharacterTurn(this.text, {this.done = false});
  final String text;
  final bool done;
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
