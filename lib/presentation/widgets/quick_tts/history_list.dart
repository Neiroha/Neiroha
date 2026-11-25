import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/audio_download.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/providers/session_audio_provider.dart';

class QuickTtsHistoryList extends ConsumerWidget {
  const QuickTtsHistoryList({
    super.key,
    required this.historyAsync,
    required this.onSave,
  });
  final AsyncValue<List<db.QuickTtsHistory>> historyAsync;
  final Future<void> Function(db.QuickTtsHistory) onSave;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return historyAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 36,
                  color: context.fg.withValues(alpha: 0.1),
                ),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).uiTypeBelowToTestThisVoice,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fg.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          );
        }

        final playback = ref.watch(
          playbackNotifierProvider.select(
            (state) => (audioPath: state.audioPath, isPlaying: state.isPlaying),
          ),
        );
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: history.length,
          itemBuilder: (ctx, i) {
            final entry = history[i];
            final isPlaying =
                entry.audioPath != null &&
                playback.audioPath == entry.audioPath &&
                playback.isPlaying;
            final hasAudio = entry.audioPath != null;
            final hasError = entry.error != null;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.inputText,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fg.withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasError)
                          Tooltip(
                            message: entry.error!,
                            child: const Icon(
                              Icons.error_rounded,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                          ),
                        IconButton(
                          onPressed: () async {
                            if (kIsWeb) {
                              if (hasAudio &&
                                  playback.audioPath == entry.audioPath) {
                                await ref
                                    .read(playbackNotifierProvider.notifier)
                                    .stop();
                              }
                              if (context.mounted) {
                                ref
                                    .read(sessionAudioProvider.notifier)
                                    .delete(entry.id);
                              }
                              return;
                            }
                            if (entry.audioPath != null) {
                              final file = File(entry.audioPath!);
                              if (file.existsSync()) {
                                await file.delete();
                              }
                            }
                            await ref
                                .read(databaseProvider)
                                .deleteQuickTtsHistory(entry.id);
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: context.fg.withValues(alpha: 0.3),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          tooltip: AppLocalizations.of(context).uiDelete,
                        ),
                      ],
                    ),
                    if (hasAudio) ...[
                      SizedBox(height: 6),
                      _buildAudioRow(context, ref, entry, isPlaying),
                    ],
                    if (hasAudio) _buildAssetActionRow(context, ref, entry),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioRow(
    BuildContext context,
    WidgetRef ref,
    db.QuickTtsHistory entry,
    bool isPlaying,
  ) {
    String durationText = '--:--';
    if (entry.audioDuration != null) {
      final totalSecs = entry.audioDuration!;
      final mins = (totalSecs / 60).floor();
      final secs = (totalSecs % 60).floor();
      durationText =
          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final notifier = ref.read(playbackNotifierProvider.notifier);
            if (isPlaying) {
              await notifier.stop();
            } else {
              await notifier.load(
                entry.audioPath!,
                entry.inputText,
                subtitle: entry.voiceName,
                sourceTag: voiceBankQuickTestPlaybackSource,
              );
            }
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 10),
        Text(
          isPlaying ? 'Playing…' : 'Tap to play',
          style: TextStyle(
            fontSize: 11,
            color: isPlaying
                ? AppTheme.accentColor
                : context.fg.withValues(alpha: 0.4),
          ),
        ),
        const Spacer(),
        Text(
          durationText,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: isPlaying
                ? AppTheme.accentColor
                : context.fg.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetActionRow(
    BuildContext context,
    WidgetRef ref,
    db.QuickTtsHistory entry,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!kIsWeb)
            TextButton.icon(
              onPressed: () => _download(context, ref, entry),
              style: TextButton.styleFrom(
                foregroundColor: context.fg.withValues(alpha: 0.70),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 24),
                textStyle: const TextStyle(fontSize: 11),
              ),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: Text(AppLocalizations.of(context).playbackDownload),
            ),
          TextButton.icon(
            onPressed: kIsWeb
                ? () =>
                      ref.read(sessionAudioProvider.notifier).download(entry.id)
                : () => onSave(entry),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
              textStyle: const TextStyle(fontSize: 11),
            ),
            icon: const Icon(
              kIsWeb ? Icons.download_rounded : Icons.library_add_rounded,
              size: 14,
            ),
            label: Text(
              kIsWeb
                  ? AppLocalizations.of(context).webDownloadAudio
                  : AppLocalizations.of(context).uiSaveAsVoiceAsset,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    db.QuickTtsHistory entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await downloadGeneratedAudio(
        ref,
        entry.audioPath!,
        title: entry.inputText,
      );
      if (saved) messenger.showSnackBar(SnackBar(content: Text(l10n.uiSaved)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.uiFailedToSave(error))),
      );
    }
  }
}
