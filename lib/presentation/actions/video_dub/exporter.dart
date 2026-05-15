import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/export_progress.dart';
import 'package:neiroha/presentation/widgets/video_dub/tracks.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:path/path.dart' as p;

/// Mux the project into a single MP4: V1 video + (optional) original
/// audio + every generated TTS cue + every imported A3 audio clip,
/// each delayed to its start time. Image clips on V2 and A1 gating
/// are deliberately skipped — see plan.md candidate (7).
///
/// The caller owns the "exporting" UI flag — flip it before/after.
Future<void> exportVideoDubVideo({
  required BuildContext context,
  required WidgetRef ref,
  required db.VideoDubProject project,
  required List<db.SubtitleCue> cues,
  required List<db.TimelineClip> clips,
  required bool muteVideoAudio,
  required Duration playerDuration,
}) async {
  final src = project.videoPath;
  if (src == null) return;
  if (!File(src).existsSync()) {
    _snack(context, AppLocalizations.of(context).uiSourceVideoMissingOnDisk);
    return;
  }
  final exportDubbedVideoTitle = AppLocalizations.of(
    context,
  ).uiExportDubbedVideo;
  final chooseExportFolderTitle = AppLocalizations.of(
    context,
  ).uiChooseExportFolder;
  final exportingVideoTaskLabel = AppLocalizations.of(context).uiExportingVideo;
  final ffmpeg = ref.read(ffmpegServiceProvider);
  if (!await ffmpeg.isAvailable()) {
    if (!context.mounted) return;
    _snack(
      context,
      AppLocalizations.of(
        context,
      ).uiFFmpegIsRequiredForExportConfigureItInSettings2,
    );
    return;
  }

  final overlays = <_AudioOverlay>[
    for (final c in cues)
      if (c.audioPath != null && File(c.audioPath!).existsSync())
        _AudioOverlay(path: c.audioPath!, startMs: c.startMs),
    for (final c in clips)
      if (c.laneIndex == DubLanes.a3 && File(c.audioPath).existsSync())
        _AudioOverlay(path: c.audioPath, startMs: c.startTimeMs),
  ];

  final defaultName = '${_safeFileStem(project.name)}_dubbed.mp4';
  String? outPath;
  try {
    outPath = await FilePicker.platform.saveFile(
      dialogTitle: exportDubbedVideoTitle,
      fileName: defaultName,
      type: FileType.video,
    );
  } catch (_) {
    // Some platforms don't implement saveFile — fall back to picking a
    // directory and synthesising the filename ourselves.
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: chooseExportFolderTitle,
    );
    if (dir != null && dir.isNotEmpty) {
      outPath = p.join(dir, defaultName);
    }
  }
  if (outPath == null || outPath.isEmpty) return;
  if (!outPath.toLowerCase().endsWith('.mp4')) outPath = '$outPath.mp4';

  final ffmpegPath = await ffmpeg.resolvePath();
  final prefs = await ref.read(exportPrefsServiceProvider).load();
  final args = _buildVideoExportArgs(
    videoPath: src,
    includeOriginalAudio: !muteVideoAudio,
    overlays: overlays,
    outPath: outPath,
    videoCodec: prefs.videoFfmpegCodec,
    audioCodec: prefs.videoAudioFfmpegCodec,
  );
  try {
    // Total duration for the progress bar — prefer the live media_kit
    // duration; fall back to the longest overlay end if the player
    // hasn't probed yet.
    var totalMs = playerDuration.inMilliseconds;
    if (totalMs <= 0) {
      for (final o in overlays) {
        if (o.startMs > totalMs) totalMs = o.startMs;
      }
    }
    if (!context.mounted) return;
    final result = await runFfmpegWithProgress(
      context: context,
      ffmpegPath: ffmpegPath,
      args: args,
      totalDurationMs: totalMs,
      taskLabel: exportingVideoTaskLabel,
    );
    if (!context.mounted) return;
    if (result.success) {
      // Default behaviour: write a sidecar .srt next to the .mp4 so
      // downstream players (and Premiere/DaVinci/VLC) pick it up
      // automatically. Soft-muxing with `-c:s mov_text` would only
      // benefit MP4-aware players and would force re-encoding any
      // non-MP4 container the user types into the save dialog.
      final srtPath = _replaceExtension(outPath, '.srt');
      String? sidecarErr;
      try {
        await File(srtPath).writeAsString(_cuesToSrt(cues));
      } catch (e) {
        sidecarErr = '$e';
      }
      if (!context.mounted) return;
      await showExportSuccessDialog(
        context: context,
        filePath: outPath,
        extraNote: sidecarErr == null
            ? AppLocalizations.of(
                context,
              ).uiSRTSidecarWrittenTo(p.basename(srtPath))
            : AppLocalizations.of(context).uiSidecarSRTFailed(sidecarErr),
      );
    } else if (result.cancelled) {
      _snack(context, AppLocalizations.of(context).uiExportCancelled);
    } else {
      _snack(
        context,
        AppLocalizations.of(context).uiExportFailed(result.stderrTail),
      );
    }
  } catch (e) {
    if (context.mounted) {
      _snack(context, AppLocalizations.of(context).uiExportFailed(e));
    }
  }
}

/// Audio-only export: subtitles' generated TTS + A3 imports + (if not
/// muted) the original video's audio, mixed onto a single WAV. Lets
/// the user mux the dubbed audio back over the video in another tool
/// (Premiere, DaVinci, Audacity, …).
Future<void> exportVideoDubAudio({
  required BuildContext context,
  required WidgetRef ref,
  required db.VideoDubProject project,
  required List<db.SubtitleCue> cues,
  required List<db.TimelineClip> clips,
  required bool muteVideoAudio,
  required Duration playerDuration,
}) async {
  final exportDubbedAudioTitle = AppLocalizations.of(
    context,
  ).uiExportDubbedAudio;
  final chooseExportFolderTitle = AppLocalizations.of(
    context,
  ).uiChooseExportFolder;
  final exportingAudioTaskLabel = AppLocalizations.of(context).uiExportingAudio;
  final nothingToExportMessage = AppLocalizations.of(
    context,
  ).uiNothingToExportNoGeneratedTTSA3AudioOrUnmutedV1;
  final ffmpeg = ref.read(ffmpegServiceProvider);
  if (!await ffmpeg.isAvailable()) {
    if (!context.mounted) return;
    _snack(
      context,
      AppLocalizations.of(
        context,
      ).uiFFmpegIsRequiredForExportConfigureItInSettings2,
    );
    return;
  }

  final overlays = <_AudioOverlay>[
    for (final c in cues)
      if (c.audioPath != null && File(c.audioPath!).existsSync())
        _AudioOverlay(path: c.audioPath!, startMs: c.startMs),
    for (final c in clips)
      if (c.laneIndex == DubLanes.a3 && File(c.audioPath).existsSync())
        _AudioOverlay(path: c.audioPath, startMs: c.startTimeMs),
  ];

  // Original video audio is opt-in: include it only when the user
  // hasn't muted it AND we actually have a source video.
  final src = project.videoPath;
  final includeOriginal =
      !muteVideoAudio && src != null && File(src).existsSync();

  if (overlays.isEmpty && !includeOriginal) {
    if (!context.mounted) return;
    _snack(context, nothingToExportMessage);
    return;
  }

  final prefs = await ref.read(exportPrefsServiceProvider).load();
  final ext = prefs.audioExtension;
  final defaultName = '${_safeFileStem(project.name)}_dub$ext';
  String? outPath;
  try {
    outPath = await FilePicker.platform.saveFile(
      dialogTitle: exportDubbedAudioTitle,
      fileName: defaultName,
      type: FileType.audio,
    );
  } catch (_) {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: chooseExportFolderTitle,
    );
    if (dir != null && dir.isNotEmpty) outPath = p.join(dir, defaultName);
  }
  if (outPath == null || outPath.isEmpty) return;
  if (!outPath.toLowerCase().endsWith(ext)) outPath = '$outPath$ext';

  final ffmpegPath = await ffmpeg.resolvePath();
  final args = _buildAudioExportArgs(
    sourceVideoPath: includeOriginal ? src : null,
    overlays: overlays,
    outPath: outPath,
    audioCodec: prefs.audioFfmpegCodec,
  );
  try {
    // Approximate total duration for the progress bar — longest
    // overlay end, plus the source video's length if it's mixed in.
    var totalMs = 0;
    for (final o in overlays) {
      if (o.startMs > totalMs) totalMs = o.startMs;
    }
    if (includeOriginal && playerDuration.inMilliseconds > totalMs) {
      totalMs = playerDuration.inMilliseconds;
    }
    if (!context.mounted) return;
    final result = await runFfmpegWithProgress(
      context: context,
      ffmpegPath: ffmpegPath,
      args: args,
      totalDurationMs: totalMs,
      taskLabel: exportingAudioTaskLabel,
    );
    if (!context.mounted) return;
    if (result.success) {
      await showExportSuccessDialog(context: context, filePath: outPath);
    } else if (result.cancelled) {
      _snack(context, AppLocalizations.of(context).uiExportCancelled);
    } else {
      _snack(
        context,
        AppLocalizations.of(context).uiAudioExportFailed(result.stderrTail),
      );
    }
  } catch (e) {
    if (context.mounted) {
      _snack(context, AppLocalizations.of(context).uiAudioExportFailed(e));
    }
  }
}

/// Batch-export the project's cues as an SRT plus a folder of the
/// generated TTS audio files. Lets the user feed the dubbing material
/// into another tool (Premiere, DaVinci, Audacity, …) without needing
/// this app to mux the final cut.
Future<void> exportVideoDubSubtitlesAndTts({
  required BuildContext context,
  required db.VideoDubProject project,
  required List<db.SubtitleCue> cues,
}) async {
  if (cues.isEmpty) return;
  final dir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: AppLocalizations.of(
      context,
    ).uiChooseExportFolderForSubtitlesTTSFiles,
  );
  if (dir == null || dir.isEmpty) return;

  final stem = _safeFileStem(project.name);
  final outDir = Directory(p.join(dir, '${stem}_export'));
  final ttsDir = Directory(p.join(outDir.path, 'tts'));
  try {
    await outDir.create(recursive: true);
    await ttsDir.create(recursive: true);

    // Write SRT.
    final srtBuf = StringBuffer();
    // SRT generation lives in _cuesToSrt — same format as the
    // sidecar produced alongside Export Video.
    srtBuf.write(_cuesToSrt(cues));
    await File(
      p.join(outDir.path, '$stem.srt'),
    ).writeAsString(srtBuf.toString());

    // Copy TTS audio files alongside, named so they sort by cue order.
    var copied = 0;
    var missing = 0;
    for (var i = 0; i < cues.length; i++) {
      final c = cues[i];
      if (c.audioPath == null) {
        missing++;
        continue;
      }
      final src = File(c.audioPath!);
      if (!src.existsSync()) {
        missing++;
        continue;
      }
      final ext = p.extension(c.audioPath!);
      final ord = (i + 1).toString().padLeft(3, '0');
      final destName = 'cue_${ord}_${_msToFilename(c.startMs)}$ext';
      await src.copy(p.join(ttsDir.path, destName));
      copied++;
    }

    // Manifest: cue → file mapping in case the consumer wants to
    // script timing without re-parsing the SRT.
    final manifest = StringBuffer()
      ..writeln('# Cue manifest — start_ms\tend_ms\tfile\ttext');
    for (var i = 0; i < cues.length; i++) {
      final c = cues[i];
      final file = c.audioPath == null
          ? '-'
          : 'tts/cue_${(i + 1).toString().padLeft(3, '0')}_${_msToFilename(c.startMs)}${p.extension(c.audioPath!)}';
      final text = c.cueText.replaceAll('\t', ' ').replaceAll('\n', ' ');
      manifest.writeln('${c.startMs}\t${c.endMs}\t$file\t$text');
    }
    await File(
      p.join(outDir.path, 'manifest.tsv'),
    ).writeAsString(manifest.toString());

    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      _snack(
        context,
        missing > 0
            ? l10n.uiExportedCuesAudioFilesToMissing(
                cues.length,
                copied,
                outDir.path,
                missing,
              )
            : l10n.uiExportedCuesAudioFilesTo(cues.length, copied, outDir.path),
      );
    }
  } catch (e) {
    if (context.mounted) {
      _snack(context, AppLocalizations.of(context).uiExportFailed(e));
    }
  }
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// One audio source going into the muxed export, delayed to its cue /
/// clip start.
class _AudioOverlay {
  final String path;
  final int startMs;
  const _AudioOverlay({required this.path, required this.startMs});
}

/// SRT text for [cues] using the canonical `HH:MM:SS,mmm` timestamp
/// format. Cues are emitted in their list order — the caller is
/// responsible for sorting if needed (the stream provider already
/// orders by `orderIndex`).
String _cuesToSrt(List<db.SubtitleCue> cues) {
  final buf = StringBuffer();
  for (var i = 0; i < cues.length; i++) {
    final c = cues[i];
    buf.writeln('${i + 1}');
    buf.writeln('${_msToSrt(c.startMs)} --> ${_msToSrt(c.endMs)}');
    buf.writeln(c.cueText);
    buf.writeln();
  }
  return buf.toString();
}

/// Swap a path's extension. `foo.mp4` → `_replaceExtension(_, '.srt')`
/// → `foo.srt`. If the path has no extension, appends.
String _replaceExtension(String path, String newExt) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  if (dot <= slash) return '$path$newExt';
  return '${path.substring(0, dot)}$newExt';
}

/// Build the ffmpeg argv for the muxed export.
///
/// Truncation history: an earlier draft used `duration=first` +
/// `-shortest`, which truncated the output to the first overlay (a
/// 2-second TTS cue could shrink a 10-minute video to 2 seconds).
/// Both knobs are now reversed: `duration=longest` so amix doesn't
/// stop early, and no `-shortest` so the video copy drives length.
List<String> _buildVideoExportArgs({
  required String videoPath,
  required bool includeOriginalAudio,
  required List<_AudioOverlay> overlays,
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
/// [_buildVideoExportArgs] but never touches a video stream. The output
/// codec is chosen by the caller (driven by `ExportPrefs`); the file
/// extension on [outPath] should match.
List<String> _buildAudioExportArgs({
  required String? sourceVideoPath,
  required List<_AudioOverlay> overlays,
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

String _safeFileStem(String s) {
  final cleaned = s
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  return cleaned.isEmpty ? 'project' : cleaned;
}

String _msToSrt(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final msR = d.inMilliseconds.remainder(1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)},${msR.toString().padLeft(3, '0')}';
}

String _msToFilename(int ms) {
  // mm-ss-mmm — sortable, filesystem-safe.
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  final msR = d.inMilliseconds.remainder(1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(m)}-${two(s)}-${msR.toString().padLeft(3, '0')}';
}
