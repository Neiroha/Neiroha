import 'package:neiroha/domain/ai/media/speech_segment.dart';

/// Turns VAD utterances into subtitle-sized chunks: neighbours closer than
/// [mergeGap] join while the result stays under [maxChunk]; anything longer
/// is split evenly.
List<SpeechSegment> planSubtitleChunks(
  List<SpeechSegment> speech, {
  Duration maxChunk = const Duration(seconds: 8),
  Duration mergeGap = const Duration(milliseconds: 350),
}) {
  final merged = <SpeechSegment>[];
  for (final s in speech) {
    final last = merged.isEmpty ? null : merged.last;
    if (last != null &&
        s.start - last.end <= mergeGap &&
        s.end - last.start <= maxChunk) {
      merged.last = SpeechSegment(last.start, s.end);
    } else {
      merged.add(s);
    }
  }
  return [
    for (final s in merged)
      if (s.duration <= maxChunk)
        s
      else
        ..._split(
          s,
          (s.duration.inMicroseconds / maxChunk.inMicroseconds).ceil(),
        ),
  ];
}

Iterable<SpeechSegment> _split(SpeechSegment s, int parts) sync* {
  final step = s.duration.inMicroseconds ~/ parts;
  for (var i = 0; i < parts; i++) {
    yield SpeechSegment(
      s.start + Duration(microseconds: step * i),
      i == parts - 1 ? s.end : s.start + Duration(microseconds: step * (i + 1)),
    );
  }
}
