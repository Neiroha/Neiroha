import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/presentation/widgets/export_progress.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:path/path.dart' as p;

Future<void> exportPhaseTtsMergedAudio({
  required BuildContext context,
  required WidgetRef ref,
  required db.PhaseTtsProject project,
  required List<db.PhaseTtsSegment> segments,
}) async {
  final ordered = [...segments]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final inputs = [
    for (final segment in ordered)
      if (segment.audioPath != null &&
          !segment.missing &&
          File(segment.audioPath!).existsSync())
        segment.audioPath!,
  ];
  if (inputs.isEmpty) {
    _snack(context, 'No generated segments to merge.');
    return;
  }

  final ffmpeg = ref.read(ffmpegServiceProvider);
  if (!await ffmpeg.isAvailable()) {
    if (!context.mounted) return;
    _snack(context, 'FFmpeg is required for export - configure it in Settings');
    return;
  }

  final defaultExt = _defaultExtension(inputs);
  final defaultName =
      '${_safeFileStem(project.name)}_merged_${PathService.formatTimestamp()}$defaultExt';
  String? outPath;
  try {
    outPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export merged audio',
      fileName: defaultName,
      type: FileType.audio,
    );
  } catch (_) {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export folder',
    );
    if (dir != null && dir.isNotEmpty) outPath = p.join(dir, defaultName);
  }
  if (outPath == null || outPath.isEmpty) return;
  if (p.extension(outPath).isEmpty) outPath = '$outPath$defaultExt';

  final outFile = File(outPath);
  if (!await outFile.parent.exists()) {
    await outFile.parent.create(recursive: true);
  }

  final listFile = File(
    p.join(
      outFile.parent.path,
      '.phase_concat_${DateTime.now().microsecondsSinceEpoch}.txt',
    ),
  );

  try {
    await listFile.writeAsString(_concatFileList(inputs), flush: true);
    final ffmpegPath = await ffmpeg.resolvePath();
    final ext = p.extension(outPath).toLowerCase();
    final args = [
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listFile.path,
      '-c:a',
      _audioCodecForExt(ext),
      outPath,
    ];
    if (!context.mounted) return;
    final result = await runFfmpegWithProgress(
      context: context,
      ffmpegPath: ffmpegPath,
      args: args,
      totalDurationMs: _totalDurationMs(ordered),
      taskLabel: 'Merging audio...',
    );
    if (!context.mounted) return;
    if (result.success) {
      await showExportSuccessDialog(context: context, filePath: outPath);
    } else if (result.cancelled) {
      _snack(context, 'Export cancelled');
    } else {
      _snack(context, 'Audio export failed: ${result.stderrTail}');
    }
  } catch (e) {
    if (context.mounted) _snack(context, 'Audio export failed: $e');
  } finally {
    try {
      if (await listFile.exists()) await listFile.delete();
    } catch (_) {}
  }
}

String _concatFileList(List<String> inputPaths) {
  final buffer = StringBuffer();
  for (final raw in inputPaths) {
    final normalized = raw.replaceAll('\\', '/').replaceAll("'", r"'\''");
    buffer.writeln("file '$normalized'");
  }
  return buffer.toString();
}

int _totalDurationMs(List<db.PhaseTtsSegment> segments) {
  var total = 0;
  for (final segment in segments) {
    final duration = segment.audioDuration;
    if (segment.audioPath == null || segment.missing || duration == null) {
      continue;
    }
    total += (duration * 1000).round();
  }
  return total;
}

String _defaultExtension(List<String> inputs) {
  final exts = inputs
      .map((path) => p.extension(path).toLowerCase())
      .where((ext) => ext.isNotEmpty)
      .toSet();
  if (exts.length == 1 && exts.first == '.mp3') return '.mp3';
  return '.wav';
}

String _audioCodecForExt(String ext) {
  switch (ext) {
    case '.mp3':
      return 'libmp3lame';
    case '.m4a':
    case '.aac':
      return 'aac';
    case '.ogg':
    case '.opus':
      return 'libopus';
    case '.flac':
      return 'flac';
    case '.wav':
    default:
      return 'pcm_s16le';
  }
}

String _safeFileStem(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
  return cleaned.isEmpty ? 'phase_tts' : cleaned;
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
