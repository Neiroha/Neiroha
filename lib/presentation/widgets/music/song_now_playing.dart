import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/music/song_library.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/playback_provider.dart';

import 'song_list.dart';

/// Playback tag of the song page; the detail follows only its own audio.
const songStudioPlaybackSource = 'song_studio';

/// A gradient cover drawn from the title, so every song looks its own.
class SongCover extends StatelessWidget {
  const SongCover({
    super.key,
    required this.title,
    this.size = 48,
    this.playing = false,
  });
  final String title;
  final double size;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final hue = (title.hashCode % 360).abs().toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 50) % 360, 0.6, 0.28).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
      ),
      child: Icon(
        playing ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
        size: size * 0.45,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// The selected song: cover, details, transport and lyrics that follow the
/// playback position.
class SongDetail extends ConsumerWidget {
  const SongDetail({
    super.key,
    required this.song,
    required this.onPlay,
    required this.onAction,
  });
  final SongRecord song;
  final ValueChanged<SongRecord> onPlay;
  final void Function(SongRecord song, SongAction action) onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final when = MaterialLocalizations.of(context);
    final state = ref.watch(playbackNotifierProvider);
    final loaded =
        state.sourceTag == songStudioPlaybackSource &&
        state.audioPath == song.audioPath;
    final playing = loaded && state.isPlaying;
    final tags = [
      for (final part in song.prompt.split(RegExp(r'[,，、\n]')))
        if (part.trim().isNotEmpty && part.trim().length <= 24) part.trim(),
    ].take(8);
    final progress = loaded && state.duration > Duration.zero
        ? state.position.inMilliseconds / state.duration.inMilliseconds
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SongCover(title: song.title, size: 112, playing: playing),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loaded)
                      Text(
                        l.musicNowPlaying,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    Text(
                      song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.provider} · ${song.model} · '
                      '${when.formatShortDate(song.created)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in tags)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              t,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => loaded
                    ? ref.read(playbackNotifierProvider.notifier).togglePlay()
                    : onPlay(song),
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(playing ? l.musicPause : l.musicPlay),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l.musicReuse,
                icon: const Icon(Icons.replay_rounded),
                onPressed: () => onAction(song, SongAction.reuse),
              ),
              IconButton(
                tooltip: l.musicSaveAs,
                icon: const Icon(Icons.save_alt_rounded),
                onPressed: () => onAction(song, SongAction.saveAs),
              ),
              IconButton(
                tooltip: l.musicShowInFolder,
                icon: const Icon(Icons.folder_open_rounded),
                onPressed: () => onAction(song, SongAction.showInFolder),
              ),
              IconButton(
                tooltip: l.musicDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
                onPressed: () => onAction(song, SongAction.delete),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: LinearProgressIndicator(
            value: progress ?? 0,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: SyncedLyrics(
            song: song,
            position: loaded ? state.position : null,
          ),
        ),
      ],
    );
  }
}

/// Lyrics by section. While the song plays, the current line lights up and
/// stays in view; tapping a timed line seeks there.
class SyncedLyrics extends ConsumerStatefulWidget {
  const SyncedLyrics({super.key, required this.song, this.position});
  final SongRecord song;

  /// Playback position when this song is the one loaded.
  final Duration? position;

  @override
  ConsumerState<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<SyncedLyrics> {
  final _keys = <int, GlobalKey>{};
  int? _shown;

  static String _stamp(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Index of the line playing at [pos]: the last one started before it.
  int? _active(List<LyricLine> lines, Duration? pos) {
    if (pos == null) return null;
    int? hit;
    for (final (i, line) in lines.indexed) {
      final start = line.start;
      if (start == null || start > pos) continue;
      if (line.end != null && line.end! < pos) continue;
      hit = i;
    }
    return hit;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final lines = widget.song.lyrics;
    final active = _active(lines, widget.position);
    if (active != null && active != _shown) {
      _shown = active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _keys[active]?.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.35,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
    final timed = lines.any((x) => x.start != null);
    String? section;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Row(
          children: [
            Text(l.musicLyricsTitle, style: theme.titleSmall),
            const Spacer(),
            if (timed)
              Text(
                l.musicSeekHint,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Text(l.musicNoLyrics, style: const TextStyle(color: Colors.white38)),
        for (final (i, line) in lines.indexed) ...[
          if (line.section != null && line.section != section)
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Text(
                (section = line.section)!,
                style: theme.labelSmall?.copyWith(color: Colors.white38),
              ),
            ),
          InkWell(
            key: _keys.putIfAbsent(i, GlobalKey.new),
            borderRadius: BorderRadius.circular(6),
            onTap: line.start == null
                ? null
                : () => ref
                      .read(playbackNotifierProvider.notifier)
                      .seek(line.start!),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line.start != null)
                    SizedBox(
                      width: 48,
                      child: Text(
                        _stamp(line.start!),
                        style: theme.bodySmall?.copyWith(color: Colors.white38),
                      ),
                    ),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: i == active ? 16 : 14,
                        height: 1.4,
                        fontWeight: i == active
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: i == active
                            ? AppTheme.accentColor
                            : active == null
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      child: Text(line.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Whether [song] matches a search over title, style and lyrics.
bool songMatches(SongRecord song, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return song.title.toLowerCase().contains(q) ||
      song.prompt.toLowerCase().contains(q) ||
      song.lyrics.any((x) => x.text.toLowerCase().contains(q));
}
