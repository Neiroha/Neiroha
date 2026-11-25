import 'dart:typed_data';

sealed class AiSessionEvent {
  const AiSessionEvent();
}

/// Partial (non-final) text. [itemId] groups deltas of one turn.
class TranscriptDelta extends AiSessionEvent {
  const TranscriptDelta(this.text, {this.itemId, this.source = false});
  final String text;
  final String? itemId;

  /// True for the source-language transcript of a translation session.
  final bool source;
}

class TranscriptFinal extends AiSessionEvent {
  const TranscriptFinal(this.text, {this.itemId, this.languages = const []});
  final String text;
  final String? itemId;
  final List<String> languages;
}

/// PCM16 mono audio produced by the model. [itemId] names the reply it
/// belongs to (to truncate it on barge-in).
class AudioDelta extends AiSessionEvent {
  const AudioDelta(this.pcm, {required this.sampleRate, this.itemId});
  final Uint8List pcm;
  final int sampleRate;
  final String? itemId;
}

/// The model wants a function run; answer with its result.
class FunctionCallRequested extends AiSessionEvent {
  const FunctionCallRequested({
    required this.callId,
    required this.name,
    required this.arguments,
  });
  final String callId;
  final String name;

  /// Raw JSON text.
  final String arguments;
}

class SpeechStarted extends AiSessionEvent {
  const SpeechStarted();
}

class SpeechStopped extends AiSessionEvent {
  const SpeechStopped();
}

/// A model response (realtime) or the whole session (translation) ended.
class ResponseDone extends AiSessionEvent {
  const ResponseDone({this.usage = const {}, this.text});
  final Map<String, Object?> usage;
  final String? text;
}
