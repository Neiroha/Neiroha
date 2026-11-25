class SpeechSegment {
  const SpeechSegment(this.start, this.end);
  final Duration start;
  final Duration end;
  Duration get duration => end - start;
  @override
  String toString() => '[${start.inMilliseconds}–${end.inMilliseconds} ms]';
}
