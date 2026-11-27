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
    final playback = ref.watch(
      playbackNotifierProvider.select(
        (state) => (
          audioPath: state.audioPath,
          sourceTag: state.sourceTag,
          isPlaying: state.isPlaying,
        ),
      ),
    );
    final isNovelAudio =
        playback.audioPath != null && playback.sourceTag == playbackSourceTag;
    final selectedIsActiveRead =
        readingActive &&
        selectedSegment != null &&
        selectedSegment!.globalIndex == activePlaybackGlobalIndex;
    final showStopForSelection =
        selectedIsActiveRead && (!isNovelAudio || playback.isPlaying);
    final notifier = ref.read(playbackNotifierProvider.notifier);
    final cached = segments
        .where(
          (segment) =>
              (segment.audioPath != null && !segment.missing) ||
              _shouldSkipSegment(project, segment),
        )
        .length;
    final cacheProgress = segments.isEmpty ? 0.0 : cached / segments.length;
    final idleStatusText = generatingSegmentIds.isEmpty
        ? AppLocalizations.of(context).statusIdle
        : AppLocalizations.of(
            context,
          ).novelGeneratingShort(generatingSegmentIds.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final ultraCompact = constraints.maxWidth < 360;
        return Container(
          height: compact ? 144 : 108,
          padding: EdgeInsets.fromLTRB(
            ultraCompact
                ? 8
                : compact
                ? 10
                : 18,
            compact ? 6 : 8,
            ultraCompact
                ? 8
                : compact
                ? 10
                : 18,
            compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.86),
            border: Border(
              top: BorderSide(color: colors.muted.withValues(alpha: 0.18)),
            ),
          ),
          child: compact
              ? Column(
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          Icon(
                            Icons.cached_rounded,
                            size: 15,
                            color: colors.muted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '$cached/${segments.length}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: segments.isEmpty ? 0 : cacheProgress,
                              minHeight: 4,
                            ),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: isNovelAudio
                                ? _ReaderPlaybackTimeText(colors: colors)
                                : _ReaderIdleStatusText(
                                    text: idleStatusText,
                                    colors: colors,
                                    textAlign: TextAlign.end,
                                  ),
                          ),
                          SizedBox(width: 4),
                          SizedBox.square(
                            dimension: 30,
                            child: IconButton(
                              tooltip: playback.isPlaying ? 'Pause' : 'Resume',
                              onPressed: isNovelAudio
                                  ? notifier.togglePlay
                                  : null,
                              padding: EdgeInsets.zero,
                              iconSize: 22,
                              icon: Icon(
                                isNovelAudio && playback.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: _ReaderPlaybackSlider(enabled: isNovelAudio),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: Row(
                        children: [
                          _ReaderControlButton(
                            compact: true,
                            ultraCompact: ultraCompact,
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiPreviousChapter,
                            icon: Icons.skip_previous_rounded,
                            onPressed: onPreviousChapter,
                          ),
                          _ReaderControlButton(
                            compact: true,
                            ultraCompact: ultraCompact,
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiPreviousPage,
                            icon: Icons.chevron_left_rounded,
                            onPressed: onPreviousPage,
                          ),
                          Expanded(
                            child: ultraCompact
                                ? Center(
                                    child: SizedBox.square(
                                      dimension: 32,
                                      child: IconButton.outlined(
                                        tooltip:
                                            chapter?.title ??
                                            AppLocalizations.of(
                                              context,
                                            ).uiChapters,
                                        onPressed: () =>
                                            _openChapterPicker(context),
                                        padding: EdgeInsets.zero,
                                        iconSize: 18,
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size.square(32),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(
                                          Icons.list_alt_rounded,
                                        ),
                                      ),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () =>
                                        _openChapterPicker(context),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.list_alt_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      chapter?.title ??
                                          AppLocalizations.of(
                                            context,
                                          ).uiChapters,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                          ),
                          _ReaderToggleButton(
                            compact: true,
                            ultraCompact: ultraCompact,
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
                            compact: true,
                            ultraCompact: ultraCompact,
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
                            compact: true,
                            ultraCompact: ultraCompact,
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiReaderAppearance,
                            icon: _themeIcon(project.readerTheme),
                            onPressed: () => _openAppearance(context),
                          ),
                          _ReaderControlButton(
                            compact: true,
                            ultraCompact: ultraCompact,
                            tooltip: AppLocalizations.of(context).uiNextPage,
                            icon: Icons.chevron_right_rounded,
                            onPressed: onNextPage,
                          ),
                          _ReaderControlButton(
                            compact: true,
                            ultraCompact: ultraCompact,
                            tooltip: AppLocalizations.of(context).uiNextChapter,
                            icon: Icons.skip_next_rounded,
                            onPressed: onNextChapter,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          Icon(
                            Icons.cached_rounded,
                            size: 16,
                            color: colors.muted,
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 86,
                            child: Text(
                              '$cached/${segments.length}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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
                            child: _ReaderPlaybackSlider(enabled: isNovelAudio),
                          ),
                          SizedBox(width: 8),
                          isNovelAudio
                              ? _ReaderPlaybackTimeText(colors: colors)
                              : _ReaderIdleStatusText(
                                  text: idleStatusText,
                                  colors: colors,
                                ),
                          SizedBox(width: 8),
                          IconButton(
                            tooltip: playback.isPlaying ? 'Pause' : 'Resume',
                            onPressed: isNovelAudio
                                ? notifier.togglePlay
                                : null,
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
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiPreviousChapter,
                            icon: Icons.skip_previous_rounded,
                            onPressed: onPreviousChapter,
                          ),
                          _ReaderControlButton(
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiPreviousPage,
                            icon: Icons.chevron_left_rounded,
                            onPressed: onPreviousPage,
                          ),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openChapterPicker(context),
                              icon: const Icon(
                                Icons.list_alt_rounded,
                                size: 17,
                              ),
                              label: Text(
                                chapter?.title ??
                                    AppLocalizations.of(context).uiChapters,
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
                            tooltip: AppLocalizations.of(
                              context,
                            ).uiReaderAppearance,
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
      },
    );
  }
}
