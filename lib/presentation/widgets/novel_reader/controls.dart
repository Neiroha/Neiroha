part of '../../screens/novel_reader_screen.dart';

class _NovelReaderBottomBar extends ConsumerWidget {
  final db.NovelProject project;
  final _ReaderColors colors;
  final List<db.NovelChapter> chapters;
  final db.NovelChapter? chapter;
  final List<db.NovelSegment> segments;
  final Set<String> generatingSegmentIds;
  final bool importing;
  final db.NovelSegment? selectedSegment;
  final int? activePlaybackGlobalIndex;
  final bool readingActive;
  final String playbackSourceTag;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<String> onChapterSelected;
  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;
  final VoidCallback onAddChapter;
  final ValueChanged<db.NovelChapter> onEditChapter;
  final ValueChanged<db.NovelChapter> onDeleteChapter;
  final VoidCallback? onPlaySelected;
  final void Function(String theme, double fontSize, double lineHeight)
  onAppearanceChanged;
  final ValueChanged<bool> onOverwriteWhilePlayingChanged;
  final VoidCallback onStop;

  const _NovelReaderBottomBar({
    required this.project,
    required this.colors,
    required this.chapters,
    required this.chapter,
    required this.segments,
    required this.generatingSegmentIds,
    required this.importing,
    required this.selectedSegment,
    required this.activePlaybackGlobalIndex,
    required this.readingActive,
    required this.playbackSourceTag,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onChapterSelected,
    required this.onImportFiles,
    required this.onImportFolder,
    required this.onAddChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onPlaySelected,
    required this.onAppearanceChanged,
    required this.onOverwriteWhilePlayingChanged,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackNotifierProvider);
    final isNovelAudio =
        playback.audioPath != null && playback.sourceTag == playbackSourceTag;
    final selectedIsActiveRead =
        readingActive &&
        selectedSegment != null &&
        selectedSegment!.globalIndex == activePlaybackGlobalIndex;
    final showStopForSelection =
        selectedIsActiveRead && (!isNovelAudio || playback.isPlaying);
    final notifier = ref.read(playbackNotifierProvider.notifier);
    final durMs = playback.duration.inMilliseconds;
    final posMs = playback.position.inMilliseconds.clamp(
      0,
      durMs == 0 ? 1 : durMs,
    );
    final cached = segments
        .where(
          (segment) =>
              (segment.audioPath != null && !segment.missing) ||
              _shouldSkipSegment(project, segment),
        )
        .length;
    final cacheProgress = segments.isEmpty ? 0.0 : cached / segments.length;

    return Container(
      height: 108,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.86),
        border: Border(
          top: BorderSide(color: colors.muted.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Icon(Icons.cached_rounded, size: 16, color: colors.muted),
                SizedBox(width: 8),
                SizedBox(
                  width: 86,
                  child: Text(
                    '$cached/${segments.length}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 98,
                  child: LinearProgressIndicator(
                    value: segments.isEmpty ? 0 : cacheProgress,
                    minHeight: 4,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 11,
                      ),
                    ),
                    child: Slider(
                      min: 0,
                      max: durMs == 0 ? 1 : durMs.toDouble(),
                      value: posMs.toDouble(),
                      onChanged: !isNovelAudio || durMs == 0
                          ? null
                          : (v) => notifier.seek(
                              Duration(milliseconds: v.toInt()),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  isNovelAudio
                      ? '${_fmt(playback.position)} / ${_fmt(playback.duration)}'
                      : generatingSegmentIds.isEmpty
                      ? 'Idle'
                      : 'Generating ${generatingSegmentIds.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  tooltip: playback.isPlaying ? 'Pause' : 'Resume',
                  onPressed: isNovelAudio ? notifier.togglePlay : null,
                  icon: Icon(
                    isNovelAudio && playback.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                _ReaderControlButton(
                  tooltip: AppLocalizations.of(context).uiPreviousChapter,
                  icon: Icons.skip_previous_rounded,
                  onPressed: onPreviousChapter,
                ),
                _ReaderControlButton(
                  tooltip: AppLocalizations.of(context).uiPreviousPage,
                  icon: Icons.chevron_left_rounded,
                  onPressed: onPreviousPage,
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChapterPicker(context),
                    icon: const Icon(Icons.list_alt_rounded, size: 17),
                    label: Text(
                      chapter?.title ?? 'Chapters',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                _ReaderToggleButton(
                  tooltip: project.overwriteCacheWhilePlaying
                      ? 'Overwrite cache while reading: on'
                      : 'Overwrite cache while reading: off',
                  icon: Icons.sync_rounded,
                  selected: project.overwriteCacheWhilePlaying,
                  onPressed: () => onOverwriteWhilePlayingChanged(
                    !project.overwriteCacheWhilePlaying,
                  ),
                ),
                _ReaderControlButton(
                  tooltip: showStopForSelection
                      ? 'Stop reading'
                      : selectedIsActiveRead
                      ? 'Resume reading'
                      : 'Play selected segment',
                  icon: showStopForSelection
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: showStopForSelection
                      ? onStop
                      : selectedIsActiveRead
                      ? notifier.togglePlay
                      : onPlaySelected,
                ),
                _ReaderControlButton(
                  tooltip: AppLocalizations.of(context).uiReaderAppearance,
                  icon: _themeIcon(project.readerTheme),
                  onPressed: () => _openAppearance(context),
                ),
                _ReaderControlButton(
                  tooltip: AppLocalizations.of(context).uiNextPage,
                  icon: Icons.chevron_right_rounded,
                  onPressed: onNextPage,
                ),
                _ReaderControlButton(
                  tooltip: AppLocalizations.of(context).uiNextChapter,
                  icon: Icons.skip_next_rounded,
                  onPressed: onNextChapter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChapterPicker(BuildContext context) async {
    final result = await showDialog<_ReaderChapterPickerResult>(
      context: context,
      builder: (_) => _ReaderChapterPickerDialog(
        chapters: chapters,
        segments: segments,
        importing: importing,
        selectedChapterId: chapter?.id,
      ),
    );
    if (result == null) return;
    switch (result.action) {
      case _ReaderChapterPickerAction.select:
        final chapter = result.chapter;
        if (chapter != null) onChapterSelected(chapter.id);
      case _ReaderChapterPickerAction.importFiles:
        onImportFiles();
      case _ReaderChapterPickerAction.importFolder:
        onImportFolder();
      case _ReaderChapterPickerAction.add:
        onAddChapter();
      case _ReaderChapterPickerAction.edit:
        final chapter = result.chapter;
        if (chapter != null) onEditChapter(chapter);
      case _ReaderChapterPickerAction.delete:
        final chapter = result.chapter;
        if (chapter != null) onDeleteChapter(chapter);
    }
  }

  Future<void> _openAppearance(BuildContext context) async {
    final result = await showDialog<_ReaderAppearanceResult>(
      context: context,
      builder: (_) => _ReaderAppearanceDialog(project: project),
    );
    if (result == null) return;
    onAppearanceChanged(result.theme, result.fontSize, result.lineHeight);
  }

  IconData _themeIcon(String theme) {
    return switch (theme) {
      'paper' => Icons.article_rounded,
      'comfort' => Icons.eco_rounded,
      _ => Icons.dark_mode_rounded,
    };
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ReaderControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ReaderControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _ReaderToggleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  const _ReaderToggleButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IconButton(
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        icon: Icon(icon),
        selectedIcon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? AppTheme.accentColor.withValues(alpha: 0.22)
              : null,
          foregroundColor: selected ? AppTheme.accentColor : null,
        ),
      ),
    );
  }
}

class _ReaderChapterPickerDialog extends StatelessWidget {
  final List<db.NovelChapter> chapters;
  final List<db.NovelSegment> segments;
  final bool importing;
  final String? selectedChapterId;

  const _ReaderChapterPickerDialog({
    required this.chapters,
    required this.segments,
    required this.importing,
    required this.selectedChapterId,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final segment in segments) {
      counts[segment.chapterId] = (counts[segment.chapterId] ?? 0) + 1;
    }
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(AppLocalizations.of(context).uiChapters)),
          IconButton(
            tooltip: AppLocalizations.of(context).uiImportTXTFiles,
            onPressed: importing
                ? null
                : () => Navigator.pop(
                    context,
                    const _ReaderChapterPickerResult(
                      action: _ReaderChapterPickerAction.importFiles,
                    ),
                  ),
            icon: importing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_rounded),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiImportFolder,
            onPressed: importing
                ? null
                : () => Navigator.pop(
                    context,
                    const _ReaderChapterPickerResult(
                      action: _ReaderChapterPickerAction.importFolder,
                    ),
                  ),
            icon: const Icon(Icons.folder_open_rounded),
          ),
          IconButton.filledTonal(
            tooltip: AppLocalizations.of(context).uiAddChapter,
            onPressed: () => Navigator.pop(
              context,
              const _ReaderChapterPickerResult(
                action: _ReaderChapterPickerAction.add,
              ),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 480,
        child: chapters.isEmpty
            ? Center(
                child: Text(
                  AppLocalizations.of(
                    context,
                  ).uiImportTXTFilesImportAFolderOrAddAChapter,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              )
            : ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final selected = chapter.id == selectedChapterId;
                  return ListTile(
                    selected: selected,
                    leading: CircleAvatar(
                      radius: 15,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(chapter.title, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${counts[chapter.id] ?? 0} segments',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        if (selected)
                          Padding(
                            padding: EdgeInsets.only(top: 8, right: 2),
                            child: Icon(Icons.check_rounded),
                          ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).uiEditChapter,
                          onPressed: () => Navigator.pop(
                            context,
                            _ReaderChapterPickerResult(
                              action: _ReaderChapterPickerAction.edit,
                              chapter: chapter,
                            ),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).uiDeleteChapter,
                          onPressed: () => Navigator.pop(
                            context,
                            _ReaderChapterPickerResult(
                              action: _ReaderChapterPickerAction.delete,
                              chapter: chapter,
                            ),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _ReaderChapterPickerResult(
                        action: _ReaderChapterPickerAction.select,
                        chapter: chapter,
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
      ],
    );
  }
}

enum _ReaderChapterPickerAction {
  select,
  importFiles,
  importFolder,
  add,
  edit,
  delete,
}

class _ReaderChapterPickerResult {
  final _ReaderChapterPickerAction action;
  final db.NovelChapter? chapter;

  const _ReaderChapterPickerResult({required this.action, this.chapter});
}
