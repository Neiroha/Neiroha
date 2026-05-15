import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;

import 'package:neiroha/presentation/theme/app_theme.dart';

/// One-shot result from [runFfmpegWithProgress]. `outputPath` is set on
/// success; `stderrTail` carries the last few stderr lines on failure
/// so the caller can surface them in a snackbar.
class FfmpegRunResult {
  final bool success;
  final bool cancelled;
  final String? outputPath;
  final String stderrTail;

  const FfmpegRunResult.ok(this.outputPath)
    : success = true,
      cancelled = false,
      stderrTail = '';

  const FfmpegRunResult.cancelled()
    : success = false,
      cancelled = true,
      outputPath = null,
      stderrTail = '';

  const FfmpegRunResult.failed(this.stderrTail)
    : success = false,
      cancelled = false,
      outputPath = null;
}

/// Run [ffmpegPath] [args] while displaying a modal progress dialog.
///
/// `args` should NOT include `-progress`/`-nostats` — this helper appends
/// them. The output path is taken to be the last positional arg
/// (consistent with how [_buildExportArgs] / [_buildAudioExportArgs]
/// emit their argv).
///
/// Progress is computed from ffmpeg's `out_time_us=` lines compared
/// against [totalDurationMs]; pass 0 to render an indeterminate spinner.
Future<FfmpegRunResult> runFfmpegWithProgress({
  required BuildContext context,
  required String ffmpegPath,
  required List<String> args,
  required int totalDurationMs,
  required String taskLabel,
}) async {
  if (args.isEmpty) {
    return const FfmpegRunResult.failed('No ffmpeg arguments supplied');
  }

  final progressNotifier = ValueNotifier<double>(0.0);
  final outputPath = args.isNotEmpty ? args.last : '';

  // Inject -progress pipe:1 -nostats just before the output path.
  final ffmpegArgs = [
    ...args.sublist(0, args.length - 1),
    '-progress',
    'pipe:1',
    '-nostats',
    args.last,
  ];

  final messages = ReceivePort();
  final errors = ReceivePort();
  final exits = ReceivePort();
  final resultCompleter = Completer<FfmpegRunResult>();
  StreamSubscription<dynamic>? messageSub;
  StreamSubscription<dynamic>? errorSub;
  StreamSubscription<dynamic>? exitSub;
  Isolate? worker;
  SendPort? workerControlPort;
  var cancelRequested = false;

  void requestCancel() {
    cancelRequested = true;
    workerControlPort?.send('cancel');
  }

  // Start the dialog before the process — gives the user immediate
  // feedback even if isolate/process startup is slow on cold cache.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ProgressDialog(
        label: taskLabel,
        indeterminate: totalDurationMs <= 0,
        progress: progressNotifier,
        onCancel: requestCancel,
      ),
    ),
  );

  try {
    messageSub = messages.listen((message) {
      if (message is! List || message.isEmpty) return;
      final type = message.first;
      switch (type) {
        case 'ready':
          workerControlPort = message[1] as SendPort;
          if (cancelRequested) workerControlPort?.send('cancel');
          break;
        case 'progress':
          final value = message[1];
          if (value is num) {
            progressNotifier.value = value.toDouble().clamp(0.0, 1.0);
          }
          break;
        case 'done':
          if (resultCompleter.isCompleted) return;
          final success = message[1] == true;
          final cancelled = message[2] == true;
          final stderrTail = (message[3] as String?) ?? '';
          if (cancelled) {
            resultCompleter.complete(const FfmpegRunResult.cancelled());
          } else if (success) {
            resultCompleter.complete(FfmpegRunResult.ok(outputPath));
          } else {
            resultCompleter.complete(FfmpegRunResult.failed(stderrTail));
          }
          break;
      }
    });
    errorSub = errors.listen((message) {
      if (resultCompleter.isCompleted) return;
      resultCompleter.complete(
        FfmpegRunResult.failed('FFmpeg worker crashed: $message'),
      );
    });
    exitSub = exits.listen((_) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 1), () {
          if (resultCompleter.isCompleted) return;
          resultCompleter.complete(
            const FfmpegRunResult.failed('FFmpeg worker exited unexpectedly'),
          );
        }),
      );
    });

    worker = await Isolate.spawn<Map<String, Object?>>(
      _ffmpegProgressWorker,
      <String, Object?>{
        'sendPort': messages.sendPort,
        'ffmpegPath': ffmpegPath,
        'args': ffmpegArgs,
        'totalDurationMs': totalDurationMs,
      },
      debugName: 'ffmpeg-export',
      onError: errors.sendPort,
      onExit: exits.sendPort,
    );
  } catch (e) {
    progressNotifier.dispose();
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return FfmpegRunResult.failed('Could not start ffmpeg: $e');
  }

  final result = await resultCompleter.future;
  progressNotifier.dispose();
  await messageSub.cancel();
  await errorSub.cancel();
  await exitSub.cancel();
  messages.close();
  errors.close();
  exits.close();
  worker.kill(priority: Isolate.immediate);

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  return result;
}

void _ffmpegProgressWorker(Map<String, Object?> message) async {
  final sendPort = message['sendPort']! as SendPort;
  final ffmpegPath = message['ffmpegPath']! as String;
  final args = (message['args']! as List).cast<String>();
  final totalDurationMs = message['totalDurationMs']! as int;
  final controlPort = ReceivePort();

  Process? process;
  var cancelled = false;
  final stderrLines = <String>[];

  sendPort.send(<Object?>['ready', controlPort.sendPort]);

  final controlSub = controlPort.listen((command) {
    if (command != 'cancel') return;
    cancelled = true;
    process?.kill();
  });

  try {
    process = await Process.start(ffmpegPath, args);
    if (cancelled) process.kill();
  } catch (e) {
    await controlSub.cancel();
    controlPort.close();
    sendPort.send(<Object?>[
      'done',
      false,
      cancelled,
      'Could not start ffmpeg: $e',
    ]);
    return;
  }

  final stdoutDone = Completer<void>();
  final stderrDone = Completer<void>();

  final stderrSub = process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          if (line.trim().isEmpty) return;
          stderrLines.add(line);
          if (stderrLines.length > 24) stderrLines.removeAt(0);
        },
        onError: (_) {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
        onDone: () {
          if (!stderrDone.isCompleted) stderrDone.complete();
        },
      );

  final stdoutSub = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
        (line) {
          if (line.startsWith('out_time_us=')) {
            final us = int.tryParse(line.substring(12));
            if (us != null && totalDurationMs > 0) {
              final pct = (us / 1000 / totalDurationMs).clamp(0.0, 1.0);
              sendPort.send(<Object?>['progress', pct]);
            }
          } else if (line == 'progress=end') {
            sendPort.send(<Object?>['progress', 1.0]);
          }
        },
        onError: (_) {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
        onDone: () {
          if (!stdoutDone.isCompleted) stdoutDone.complete();
        },
      );

  final exit = await process.exitCode;
  try {
    await Future.wait<void>([
      stdoutDone.future,
      stderrDone.future,
    ]).timeout(const Duration(seconds: 1));
  } catch (_) {}
  await stdoutSub.cancel();
  await stderrSub.cancel();
  await controlSub.cancel();
  controlPort.close();

  final tail = stderrLines.length <= 4
      ? stderrLines
      : stderrLines.sublist(stderrLines.length - 4);
  sendPort.send(<Object?>['done', exit == 0, cancelled, tail.join(' / ')]);
}

class _ProgressDialog extends StatelessWidget {
  final String label;
  final bool indeterminate;
  final ValueNotifier<double> progress;
  final VoidCallback onCancel;

  const _ProgressDialog({
    required this.label,
    required this.indeterminate,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(label),
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: indeterminate ? null : value,
                  minHeight: 6,
                ),
                SizedBox(height: 10),
                Text(
                  indeterminate
                      ? AppLocalizations.of(context).uiEncoding
                      : '${(value * 100).clamp(0, 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
      ],
    );
  }
}

/// Modal "Export successful" dialog. [filePath] is shown selectable so
/// the user can copy it; "Open folder" reveals the file in the OS file
/// manager.
Future<void> showExportSuccessDialog({
  required BuildContext context,
  required String filePath,
  String? extraNote,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context).uiExportSuccessful),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            filePath,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          if (extraNote != null) ...[
            SizedBox(height: 10),
            Text(
              extraNote,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            unawaited(revealInFileManager(filePath));
          },
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: Text(AppLocalizations.of(context).uiOpenFolder),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentColor),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context).uiDone),
        ),
      ],
    ),
  );
}

/// Best-effort "open the OS file manager and select [filePath]". Falls
/// back to opening the parent directory when reveal-in-folder isn't
/// supported.
Future<void> revealInFileManager(String filePath) async {
  try {
    if (Platform.isWindows) {
      // explorer's /select, requires the file path quoted; the comma
      // must NOT have a space after it.
      await Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else {
      await Process.run('xdg-open', [p.dirname(filePath)]);
    }
  } catch (_) {
    // Best-effort — the user already has the path in the success dialog.
  }
}
