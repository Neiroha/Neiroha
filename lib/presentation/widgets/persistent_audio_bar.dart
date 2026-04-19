import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';
import '../theme/app_theme.dart';

class PersistentAudioBar extends ConsumerWidget {
  final String? onlyForSourceTag;

  const PersistentAudioBar({
    super.key,
    this.onlyForSourceTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackNotifierProvider);
    if (state.audioPath == null) return const SizedBox.shrink();
    if (onlyForSourceTag != null && state.sourceTag != onlyForSourceTag) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(playbackNotifierProvider.notifier);
    final durMs = state.duration.inMilliseconds;
    final posMs = state.position.inMilliseconds.clamp(0, durMs == 0 ? 1 : durMs);

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDim,
        border: Border(top: BorderSide(color: Color(0xFF2A2A36))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.25),
            child: Text(
              _initial(state.subtitle ?? state.title),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.subtitle != null && state.subtitle!.isNotEmpty)
                  Text(
                    state.subtitle!,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                min: 0,
                max: durMs == 0 ? 1 : durMs.toDouble(),
                value: posMs.toDouble(),
                onChanged: durMs == 0
                    ? null
                    : (v) =>
                        notifier.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmt(state.position)} / ${_fmt(state.duration)}',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white54,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              state.isPlaying
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
            tooltip: 'Close player',
            onPressed: notifier.stop,
          ),
        ],
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
