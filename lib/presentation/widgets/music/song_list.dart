import 'package:flutter/material.dart';
import 'package:neiroha/data/services/music/song_library.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

import 'song_now_playing.dart';

enum SongAction { reuse, showInFolder, saveAs, delete }

/// The song library beside the selected song's detail; stacked on narrow
/// panes.
class SongList extends StatefulWidget {
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
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = widget.songs;
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 56,
              color: context.fg.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            Text(
              l.musicEmpty,
              style: TextStyle(color: context.fg.withValues(alpha: 0.38)),
            ),
          ],
        ),
      );
    }
    final current = widget.selected ?? songs.first;
    final shown = [
      for (final s in songs)
        if (songMatches(s, _query.text)) s,
    ];
    final library = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              hintText: l.musicSearch,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text(
            l.musicCount(songs.length),
            style: TextStyle(
              fontSize: 11,
              color: context.fg.withValues(alpha: 0.38),
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    l.musicNoMatch,
                    style: TextStyle(color: context.fg.withValues(alpha: 0.38)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _SongTile(
                    song: shown[i],
                    selected: shown[i].audioPath == current.audioPath,
                    playing: shown[i].audioPath == widget.playingPath,
                    onTap: () => widget.onSelect(shown[i]),
                    onPlay: () => widget.onPlay(shown[i]),
                  ),
                ),
        ),
      ],
    );
    final detail = SongDetail(
      key: ValueKey(current.audioPath),
      song: current,
      onPlay: widget.onPlay,
      onAction: widget.onAction,
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 720
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: library),
                const VerticalDivider(width: 1),
                Expanded(child: detail),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 240, child: library),
                const Divider(height: 1),
                Expanded(child: detail),
              ],
            ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPlay,
  });
  final SongRecord song;
  final bool selected, playing;
  final VoidCallback onTap, onPlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final when = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? AppTheme.accentColor.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onDoubleTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SongCover(title: song.title, size: 44, playing: playing),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: playing ? AppTheme.accentColor : null,
                        ),
                      ),
                      Text(
                        '${song.instrumental ? '♪ ' : ''}${song.model} · '
                        '${when.formatShortDate(song.created)} '
                        '${when.formatTimeOfDay(TimeOfDay.fromDateTime(song.created))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.fg.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: playing ? l.musicNowPlaying : l.musicPlay,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    playing
                        ? Icons.graphic_eq_rounded
                        : Icons.play_circle_outline_rounded,
                    color: playing ? AppTheme.accentColor : null,
                  ),
                  onPressed: onPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
