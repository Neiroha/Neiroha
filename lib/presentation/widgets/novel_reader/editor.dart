part of '../../screens/novel_reader_screen.dart';

class _NovelReaderEditor extends ConsumerStatefulWidget {
  final String projectId;
  final VoidCallback onClose;

  const _NovelReaderEditor({
    super.key,
    required this.projectId,
    required this.onClose,
  });

  @override
  ConsumerState<_NovelReaderEditor> createState() => _NovelReaderEditorState();
}

class _NovelReaderEditorState extends ConsumerState<_NovelReaderEditor> {
  String? _manualChapterId;
  int? _manualPageIndex;
  int _playRunId = 0;
  Completer<void>? _stopCompleter;
  bool _importing = false;
  bool _generatingAll = false;
  bool _exporting = false;
  bool _editing = false;
  int? _activePlaybackGlobalIndex;
  int _prefetchRunId = 0;
  final Set<String> _generatingSegmentIds = <String>{};
  final Map<String, Future<String>> _audioTasks = <String, Future<String>>{};

  String get _playbackSourceTag =>
      novelReaderPlaybackSourceFor(widget.projectId);

  @override
  void dispose() {
    _stopNovel(updateUi: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(novelProjectsStreamProvider);
    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final chapters =
        ref.watch(novelChaptersStreamProvider(project.id)).valueOrNull ??
        const <db.NovelChapter>[];
    final segments =
        ref.watch(novelSegmentsStreamProvider(project.id)).valueOrNull ??
        const <db.NovelSegment>[];
    final allAssets =
        ref.watch(voiceAssetsStreamProvider).valueOrNull ??
        const <db.VoiceAsset>[];
    final members =
        ref.watch(bankMembersStreamProvider(project.bankId)).valueOrNull ??
        const <db.VoiceBankMember>[];
    final providers =
        ref.watch(ttsProvidersStreamProvider).valueOrNull ??
        const <db.TtsProvider>[];
    final assetMap = {for (final a in allAssets) a.id: a};
    final bankAssets = members
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();
    final chapterMap = {for (final c in chapters) c.id: c};
    final segmentCacheStates = _cacheStatesForSegments(
      project,
      segments,
      bankAssets,
      providers,
    );

    final currentIndex = segments.isEmpty
        ? 0
        : project.currentGlobalIndex.clamp(0, segments.length - 1);
    final currentSegment = segments.isEmpty
        ? null
        : segments[currentIndex.toInt()];
    final currentChapter = currentSegment == null
        ? (chapters.isEmpty ? null : chapters.first)
        : chapterMap[currentSegment.chapterId];
    final visibleChapterId = chapters.any((c) => c.id == _manualChapterId)
        ? _manualChapterId
        : currentChapter?.id;
    final chapterSegments = visibleChapterId == null
        ? <db.NovelSegment>[]
        : (segments.where((s) => s.chapterId == visibleChapterId).toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
    final visibleChapter = visibleChapterId == null
        ? null
        : chapterMap[visibleChapterId];

    return Column(
      children: [
        _NovelEditorBar(project: project, onBack: widget.onClose),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.68,
            compactRightIcon: Icons.tune_rounded,
            compactRightLabel: AppLocalizations.of(context).navSettings,
            compactHandleBottomInset: 158,
            left: _editing
                ? _ChapterEditPane(
                    project: project,
                    chapter: visibleChapter,
                    segments: chapterSegments,
                    currentGlobalIndex: currentSegment?.globalIndex,
                    onPickSegment: (segment) =>
                        unawaited(_jumpTo(project, segment, syncPage: true)),
                    onSaveSegment: (segment, text) =>
                        unawaited(_saveSegmentEdit(project, segment, text)),
                    onDeleteSegment: (segment) =>
                        unawaited(_deleteSegment(project, segment)),
                  )
                : _ReaderPane(
                    project: project,
                    chapter: visibleChapter,
                    chapters: chapters,
                    segments: chapterSegments,
                    allSegments: segments,
                    cacheStates: segmentCacheStates,
                    requestedPageIndex: _manualPageIndex,
                    currentGlobalIndex: currentSegment?.globalIndex,
                    activePlaybackGlobalIndex: _activePlaybackGlobalIndex,
                    readingActive: _stopCompleter != null,
                    playbackSourceTag: _playbackSourceTag,
                    generatingSegmentIds: _generatingSegmentIds,
                    importing: _importing,
                    onPageSelected: (index) =>
                        setState(() => _manualPageIndex = index),
                    onPickSegment: (segment) =>
                        unawaited(_jumpTo(project, segment, syncPage: true)),
                    onPlayFromSegment: (segment) => unawaited(
                      _playFromSegment(project, segment, segments, bankAssets),
                    ),
                    onChapterSelected: (chapterId) =>
                        unawaited(_selectChapter(project, chapterId, segments)),
                    onImportFiles: () => unawaited(_importFiles(project)),
                    onImportFolder: () => unawaited(_importFolder(project)),
                    onAddChapter: () =>
                        unawaited(_showChapterEditorDialog(project)),
                    onEditChapter: (chapter) => unawaited(
                      _showChapterEditorDialog(project, chapter: chapter),
                    ),
                    onDeleteChapter: (chapter) =>
                        unawaited(_deleteChapter(project, chapter)),
                    onAppearanceChanged: (theme, fontSize, lineHeight) =>
                        _updateProject(
                          project.copyWith(
                            readerTheme: theme,
                            fontSize: fontSize,
                            lineHeight: lineHeight,
                            updatedAt: DateTime.now(),
                          ),
                        ),
                    onOverwriteWhilePlayingChanged: (v) => _updateProject(
                      project.copyWith(
                        overwriteCacheWhilePlaying: v,
                        updatedAt: DateTime.now(),
                      ),
                    ),
                    onStop: () => _stopNovel(),
                  ),
            rightBuilder: (_) => _NovelSettingsPane(
              project: project,
              bankAssets: bankAssets,
              segments: segments,
              generatingSegmentIds: _generatingSegmentIds,
              importing: _importing,
              exporting: _exporting,
              hasAudio: segments.any((s) => s.audioPath != null && !s.missing),
              generatingAll: _generatingAll,
              editing: _editing,
              onNarratorChanged: (id) => _updateProject(
                project.copyWith(narratorVoiceAssetId: Value(id)),
              ),
              onDialogueChanged: (id) => _updateProject(
                project.copyWith(dialogueVoiceAssetId: Value(id)),
              ),
              onAutoTurnPageChanged: (v) => _updateProject(
                project.copyWith(autoTurnPage: v, updatedAt: DateTime.now()),
              ),
              onAutoAdvanceChaptersChanged: (v) => _updateProject(
                project.copyWith(
                  autoAdvanceChapters: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onEditingChanged: (v) {
                _stopNovel();
                setState(() {
                  _editing = v;
                  _manualPageIndex = null;
                });
              },
              onAutoSliceChanged: (v) => _updateProject(
                project.copyWith(
                  autoSliceLongSegments: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onSliceOnlyAtPunctuationChanged: (v) => _updateProject(
                project.copyWith(
                  sliceOnlyAtPunctuation: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onMaxSliceCharsChanged: (v) => _updateProject(
                project.copyWith(maxSliceChars: v, updatedAt: DateTime.now()),
              ),
              onPrefetchSegmentsChanged: (v) => _updateProject(
                project.copyWith(
                  prefetchSegments: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onOverwriteWhilePlayingChanged: (v) => _updateProject(
                project.copyWith(
                  overwriteCacheWhilePlaying: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onSkipPunctuationOnlyChanged: (v) => _updateProject(
                project.copyWith(
                  skipPunctuationOnlySegments: v,
                  updatedAt: DateTime.now(),
                ),
              ),
              onManageDialogueRules: () =>
                  unawaited(_manageDialogueRules(project, segments)),
              onCacheCurrentColorChanged: (color) => _updateProject(
                project.copyWith(
                  cacheCurrentColor: color,
                  updatedAt: DateTime.now(),
                ),
              ),
              onCacheStaleColorChanged: (color) => _updateProject(
                project.copyWith(
                  cacheStaleColor: color,
                  updatedAt: DateTime.now(),
                ),
              ),
              onCacheHighlightOpacityChanged: (opacity) => _updateProject(
                project.copyWith(
                  cacheHighlightOpacity: opacity,
                  updatedAt: DateTime.now(),
                ),
              ),
              onGenerateAll: segments.isEmpty || bankAssets.isEmpty
                  ? null
                  : () => unawaited(
                      _generateAllMissing(
                        project,
                        segments,
                        bankAssets,
                        force: false,
                      ),
                    ),
              onExport: segments.isEmpty || _exporting
                  ? null
                  : () => unawaited(_exportBook(project, segments)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateProject(db.NovelProject project) async {
    await ref
        .read(databaseProvider)
        .updateNovelProject(project.copyWith(updatedAt: DateTime.now()));
  }

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
