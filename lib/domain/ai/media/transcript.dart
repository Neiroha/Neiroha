class TranscriptWord {
  const TranscriptWord(this.text, this.start, this.end, {this.speaker});
  final String text;
  final Duration start;
  final Duration end;
  final String? speaker;
}

class Transcript {
  const Transcript(
    this.text, {
    this.languages = const [],
    this.words = const [],
    this.raw = const {},
  });
  final String text;

  /// ISO language codes the service detected, best first.
  final List<String> languages;
  final List<TranscriptWord> words;
  final Map<String, Object?> raw;
}

class TranscribeOptions {
  const TranscribeOptions({
    this.languages = const [],
    this.prompt,
    this.keywords = const [],
    this.wordTimestamps = false,
    this.diarize = false,
  });
  final List<String> languages;
  final String? prompt;
  final List<String> keywords;
  final bool wordTimestamps;
  final bool diarize;
}
