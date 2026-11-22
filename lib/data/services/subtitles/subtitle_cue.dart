/// One timed line of a transcript, optionally with its translation.
class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text, {this.translation});
  final Duration start;
  final Duration end;
  final String text;
  final String? translation;

  SubtitleCue withTranslation(String? value) =>
      SubtitleCue(start, end, text, translation: value);
}

enum SubtitleFormat {
  srt('.srt'),
  vtt('.vtt'),
  lrc('.lrc');

  const SubtitleFormat(this.extension);
  final String extension;
}

/// Which text a written file carries.
enum SubtitleTextMode { original, translation, bilingual }
