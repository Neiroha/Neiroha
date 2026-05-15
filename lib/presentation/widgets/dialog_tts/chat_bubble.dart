import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Telegram-like chat bubble for one Dialog TTS line.
///
/// Stateless: the parent owns playback / generating flags and wires the
/// row's actions back through the callbacks. Audio row renders a play
/// button + inline waveform with elapsed/total time once a clip exists.
class ChatBubble extends StatelessWidget {
  final db.DialogTtsLine line;
  final db.VoiceAsset? asset;
  final bool isPlaying;
  final bool isGenerating;
  final Duration? playbackPosition;
  final double maxBubbleWidth;
  final VoidCallback onPlay;
  final VoidCallback? onPlayFrom;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const ChatBubble({
    super.key,
    required this.line,
    required this.asset,
    required this.isPlaying,
    required this.isGenerating,
    this.playbackPosition,
    required this.maxBubbleWidth,
    required this.onPlay,
    this.onPlayFrom,
    this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = asset?.name ?? AppLocalizations.of(context).uiUnknown;
    final hasAudio = line.audioPath != null;
    final hasError = line.error != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(name),
          SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor,
                  ),
                ),
                SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBright,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.lineText,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (hasAudio || hasError) ...[
                          SizedBox(height: 8),
                          _buildAudioRow(context, hasAudio, hasError),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 4),
          if (isGenerating)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: Icon(
                line.audioPath != null
                    ? Icons.refresh_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: onGenerate == null
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppTheme.accentColor,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: line.audioPath != null
                  ? AppLocalizations.of(context).uiRegenerate
                  : AppLocalizations.of(context).uiGenerate,
              onPressed: onGenerate,
            ),
          SizedBox(width: 4),
          if (onPlayFrom != null)
            IconButton(
              icon: Icon(
                Icons.playlist_play_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: AppLocalizations.of(context).uiPlayFromHere,
              onPressed: onPlayFrom,
            ),
          SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    if (asset?.avatarPath != null && File(asset!.avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(File(asset!.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildAudioRow(BuildContext context, bool hasAudio, bool hasError) {
    if (hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_rounded, size: 16, color: Colors.redAccent),
          SizedBox(width: 6),
          Text(
            AppLocalizations.of(context).uiError,
            style: TextStyle(
              fontSize: 11,
              color: Colors.redAccent.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    final double progressFraction;
    if (isPlaying &&
        playbackPosition != null &&
        line.audioDuration != null &&
        line.audioDuration! > 0) {
      progressFraction =
          (playbackPosition!.inMilliseconds / (line.audioDuration! * 1000))
              .clamp(0.0, 1.0);
    } else {
      progressFraction = 0.0;
    }

    String timeText;
    if (isPlaying && playbackPosition != null && line.audioDuration != null) {
      final playedSecs = playbackPosition!.inSeconds;
      final totalSecs = line.audioDuration!.floor();
      timeText = '$playedSecs/$totalSecs';
    } else if (line.audioDuration != null) {
      final totalSecs = line.audioDuration!;
      final mins = (totalSecs / 60).floor();
      final secs = (totalSecs % 60).floor();
      timeText =
          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      timeText = '--:--';
    }

    const int barCount = 22;
    final waveformWidth = math.min(132.0, maxBubbleWidth * 0.45);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 8),
        SizedBox(
          width: waveformWidth,
          height: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final p = i / barCount;
              final wave1 = math.sin(p * math.pi * 4).abs();
              final wave2 = math.sin(p * math.pi * 7 + 1.2).abs();
              final wave3 = math.sin(p * math.pi * 2.5 + 0.5).abs();
              final h =
                  2.5 + (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25) * 14.0;
              final isPlayedBar = i / barCount < progressFraction;
              return Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    height: h,
                    decoration: BoxDecoration(
                      color: isPlayedBar
                          ? AppTheme.accentColor
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(width: 8),
        Text(
          timeText,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: isPlaying
                ? AppTheme.accentColor
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
