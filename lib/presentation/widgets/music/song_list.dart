import 'package:flutter/material.dart';
import 'package:neiroha/data/services/music/song_library.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Generated songs, newest first; the selected one shows its lyrics.
class SongList extends StatelessWidget {
  const SongList({
    super.key,
    required this.songs,
    required this.selected,
    required this.playingPath,
    required this.onSelect,
    required this.onPlay,
    required this.onAction,
  });

  final List<SongRecord> songs;
  final SongRecord? selected;
  final String? playingPath;
  final ValueChanged<SongRecord> onSelect;
  final ValueChanged<SongRecord> onPlay;
  final void Function(SongRecord song, SongAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (songs.isEmpty) {
      return Center(
        child: Text(
          l.musicEmpty,
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }
    final current = selected ?? songs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: songs.length,
            itemBuilder: (_, i) => _SongTile(
              song: songs[i],
              selected: songs[i].audioPath == current.audioPath,
              playing: songs[i].audioPath == playingPath,
              onTap: () => onSelect(songs[i]),
              onPlay: () => onPlay(songs[i]),
              onAction: (a) => onAction(songs[i], a),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: LyricsView(song: current)),
      ],
    );
  }
}

enum SongAction { reuse, showInFolder, saveAs, delete }

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPlay,
    required this.onAction,
  });
  final SongRecord song;
  final bool selected, playing;
  final VoidCallback onTap, onPlay;
  final ValueChanged<SongAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final when = MaterialLocalizations.of(context);
    return Card(
      color: selected ? AppTheme.surfaceBright : null,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: IconButton(
          tooltip: playing ? null : song.title,
          icon: Icon(
            playing ? Icons.graphic_eq_rounded : Icons.play_circle_rounded,
          ),
          onPressed: onPlay,
        ),
        title: Text(song.title, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${song.model} · ${when.formatShortDate(song.created)} '
          '${when.formatTimeOfDay(TimeOfDay.fromDateTime(song.created))}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: PopupMenuButton<SongAction>(
          onSelected: onAction,
          itemBuilder: (_) => [
            PopupMenuItem(value: SongAction.reuse, child: Text(l.musicReuse)),
            PopupMenuItem(
              value: SongAction.showInFolder,
              child: Text(l.musicShowInFolder),
            ),
            PopupMenuItem(value: SongAction.saveAs, child: Text(l.musicSaveAs)),
            PopupMenuItem(value: SongAction.delete, child: Text(l.musicDelete)),
          ],
        ),
      ),
    );
  }
}

/// Lyrics grouped by section, with `mm:ss` stamps when the model timed them.
class LyricsView extends StatelessWidget {
  const LyricsView({super.key, required this.song});
  final SongRecord song;

  static String _stamp(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    final lines = song.lyrics;
    String? section;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(song.title, style: theme.titleMedium),
        const SizedBox(height: 4),
        SelectableText(
          song.prompt,
          style: theme.bodySmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 16),
        if (lines.isEmpty)
          Text(l.musicNoLyrics, style: const TextStyle(color: Colors.white38)),
        for (final LyricLine line in lines) ...[
          if (line.section != null && line.section != section)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                (section = line.section)!,
                style: theme.labelSmall?.copyWith(color: Colors.white38),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
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
                Expanded(child: SelectableText(line.text)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
