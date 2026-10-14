import 'package:neiroha/data/database/app_database.dart' as db;

/// Pure (UI-free) helpers that turn a video-dub project into ffmpeg argv and
/// SRT text. Shared by the desktop exporter and the MCP server.

/// One audio source going into the muxed export, delayed to its cue /
/// clip start.
class DubAudioOverlay {
  final String path;
  final int startMs;
  const DubAudioOverlay({required this.path, required this.startMs});
}

/// SRT text for [cues] using the canonical `HH:MM:SS,mmm` timestamp
/// format. Cues are emitted in their list order — the caller is
/// responsible for sorting if needed (the stream provider already
/// orders by `orderIndex`).
String cuesToSrt(List<db.SubtitleCue> cues) {
  final buf = StringBuffer();
  for (var i = 0; i < cues.length; i++) {
    final c = cues[i];
    buf.writeln('${i + 1}');
    buf.writeln('${msToSrtStamp(c.startMs)} --> ${msToSrtStamp(c.endMs)}');
    buf.writeln(c.cueText);
    buf.writeln();
  }
  return buf.toString();
}

String msToSrtStamp(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final msR = d.inMilliseconds.remainder(1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)},${msR.toString().padLeft(3, '0')}';
}

/// Build the ffmpeg argv for the muxed export.
///
/// Truncation history: an earlier draft used `duration=first` +
/// `-shortest`, which truncated the output to the first overlay (a
/// 2-second TTS cue could shrink a 10-minute video to 2 seconds).
/// Both knobs are now reversed: `duration=longest` so amix doesn't
/// stop early, and no `-shortest` so the video copy drives length.
List<String> buildDubVideoExportArgs({
  required String videoPath,
  required bool includeOriginalAudio,
  required List<DubAudioOverlay> overlays,
  required String outPath,
  String videoCodec = 'copy',
  String audioCodec = 'aac',
}) {
  final args = <String>['-y', '-i', videoPath];
  for (final o in overlays) {
    args.addAll(['-i', o.path]);
  }
  final mixInputs = <String>[];
  final filterParts = <String>[];
  if (includeOriginalAudio) mixInputs.add('[0:a]');
  for (var i = 0; i < overlays.length; i++) {
    final inputIdx = i + 1; // 0 is the video
    final delay = overlays[i].startMs;
    final tag = 'd$i';
    // adelay applied per-channel; |-separated for stereo. The third
    // value covers the rare 3-channel case ffmpeg can produce.
    filterParts.add('[$inputIdx:a]adelay=$delay|$delay|$delay[$tag]');
    mixInputs.add('[$tag]');
  }
  if (mixInputs.isEmpty) {
    // Nothing to mix — encode video per the user's choice, drop audio.
    args.addAll(['-map', '0:v', '-c:v', videoCodec, '-an', outPath]);
    return args;
  }
  filterParts.add(
    '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest:dropout_transition=0[aout]',
  );
  args.addAll([
    '-filter_complex',
    filterParts.join(';'),
    '-map',
    '0:v',
    '-map',
    '[aout]',
    '-c:v',
    videoCodec,
    '-c:a',
    audioCodec,
    '-b:a',
    '192k',
    outPath,
  ]);
  return args;
}

/// Build the ffmpeg argv for an audio-only export. Mirrors
/// [buildDubVideoExportArgs] but never touches a video stream. The output
/// codec is chosen by the caller (driven by `ExportPrefs`); the file
/// extension on [outPath] should match.
List<String> buildDubAudioExportArgs({
  required String? sourceVideoPath,
  required List<DubAudioOverlay> overlays,
  required String outPath,
  String audioCodec = 'pcm_s16le',
}) {
  final args = <String>['-y'];
  final mixInputs = <String>[];
  final filterParts = <String>[];
  var inputIdx = 0;
  if (sourceVideoPath != null) {
    args.addAll(['-i', sourceVideoPath]);
    mixInputs.add('[$inputIdx:a]');
    inputIdx++;
  }
  for (var i = 0; i < overlays.length; i++) {
    args.addAll(['-i', overlays[i].path]);
    final delay = overlays[i].startMs;
    final tag = 'd$i';
    filterParts.add('[$inputIdx:a]adelay=$delay|$delay|$delay[$tag]');
    mixInputs.add('[$tag]');
    inputIdx++;
  }
  filterParts.add(
    '${mixInputs.join('')}amix=inputs=${mixInputs.length}:duration=longest:dropout_transition=0[aout]',
  );
  args.addAll([
    '-filter_complex',
    filterParts.join(';'),
    '-map',
    '[aout]',
    '-c:a',
    audioCodec,
    outPath,
  ]);
  return args;
}

String safeFileStem(String s) {
  final cleaned = s
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  return cleaned.isEmpty ? 'project' : cleaned;
}
