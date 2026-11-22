import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_loop.dart';
import '../../providers/playback_provider.dart';
import '../actions/audio_download.dart';
import '../theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class PersistentAudioBar extends ConsumerWidget {
  final String? onlyForSourceTag;

  const PersistentAudioBar({super.key, this.onlyForSourceTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackNotifierProvider);
    if (!state.hasMedia) return const SizedBox.shrink();
    if (onlyForSourceTag != null && state.sourceTag != onlyForSourceTag) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playbackNotifierProvider.notifier);
    final durMs = state.duration.inMilliseconds;
    final posMs = state.position.inMilliseconds.clamp(
      0,
      durMs == 0 ? 1 : durMs,
    );

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDim,
        border: Border(top: BorderSide(color: Color(0xFF2A2A36))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Embedded contexts (SegmentVoicePanel, QuickTtsPanel) are ~370px;
          // hide the time readout there so the slider keeps room. The bottom-
          // of-screen player at full width still shows it.
          final showTime = constraints.maxWidth >= 480;
          final metadataWidth = math.min(
            220.0,
            math.max(72.0, constraints.maxWidth * (showTime ? 0.34 : 0.26)),
          );
          return Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.accentColor.withValues(alpha: 0.25),
                child: Text(
                  _initial(state.subtitle ?? state.title),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: metadataWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isBuffering
                          ? AppLocalizations.of(context).uiAudioBuffering
                          : (state.title ?? ''),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (state.subtitle != null && state.subtitle!.isNotEmpty)
                      Text(
                        state.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: durMs == 0 ? 1 : durMs.toDouble(),
                    value: posMs.toDouble(),
                    onChanged: !state.canSeek
                        ? null
                        : (v) =>
                              notifier.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
              ),
              if (showTime) ...[
                SizedBox(width: 8),
                Text(
                  '${_fmt(state.position)} / ${_fmt(state.duration)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              SizedBox(width: 4),
              _PlaybackActions(state: state, compact: !showTime),
              IconButton(
                icon: Icon(
                  state.isPlaying && !state.isPaused
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                iconSize: 34,
                color: AppTheme.accentColor,
                onPressed: notifier.togglePlay,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white38,
                tooltip: AppLocalizations.of(context).uiClosePlayer,
                onPressed: notifier.stop,
              ),
            ],
          );
        },
      ),
    );
  }

  String _initial(String? s) {
    if (s == null || s.isEmpty) return '?';
    return s.characters.first.toUpperCase();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Loop and download controls; collapsed into one menu in narrow panels.
class _PlaybackActions extends ConsumerWidget {
  const _PlaybackActions({required this.state, required this.compact});

  final PlaybackState state;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final loop = ref.watch(playbackLoopProvider);
    final canLoop = !isNovelReaderPlaybackSource(state.sourceTag);
    final audioPath = state.audioPath;

    void toggleLoop() =>
        _guard(context, ref.read(playbackLoopProvider.notifier).toggle);
    void download() => _guard(context, () async {
      final saved = await downloadGeneratedAudio(
        ref,
        audioPath!,
        title: state.title,
      );
      if (saved && !kIsWeb && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.uiSaved)));
      }
    });

    if (compact) {
      return PopupMenuButton<VoidCallback>(
        tooltip: l10n.playbackMoreActions,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 28,
          height: 36,
          child: Icon(
            loop && canLoop ? Icons.repeat_one_rounded : Icons.more_vert,
            size: 18,
            color: loop && canLoop ? AppTheme.accentColor : Colors.white54,
          ),
        ),
        onSelected: (action) => action(),
        itemBuilder: (_) => [
          if (canLoop)
            CheckedPopupMenuItem(
              value: toggleLoop,
              checked: loop,
              child: Text(l10n.playbackLoop),
            ),
          PopupMenuItem(
            value: download,
            enabled: audioPath != null,
            child: Text(l10n.playbackDownload),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canLoop)
          IconButton(
            icon: Icon(
              loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              size: 18,
            ),
            color: loop ? AppTheme.accentColor : Colors.white54,
            isSelected: loop,
            tooltip: loop ? l10n.playbackLoopOn : l10n.playbackLoop,
            onPressed: toggleLoop,
          ),
        IconButton(
          icon: const Icon(Icons.download_rounded, size: 18),
          color: Colors.white54,
          tooltip: l10n.playbackDownload,
          onPressed: audioPath == null ? null : download,
        ),
      ],
    );
  }

  static Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiFailedToSave(error)),
        ),
      );
    }
  }
}
