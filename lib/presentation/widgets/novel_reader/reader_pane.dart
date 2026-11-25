part of '../../screens/novel_reader_screen.dart';

class _ReaderPane extends ConsumerWidget {
  final db.NovelProject project;
  final db.NovelChapter? chapter;
  final List<db.NovelChapter> chapters;
  final List<db.NovelSegment> segments;
  final List<db.NovelSegment> allSegments;
  final Map<String, _NovelSegmentCacheState> cacheStates;
  final int? requestedPageIndex;
  final int? currentGlobalIndex;
  final int? activePlaybackGlobalIndex;
  final bool readingActive;
  final String playbackSourceTag;
  final Set<String> generatingSegmentIds;
  final bool importing;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<db.NovelSegment> onPickSegment;
  final ValueChanged<db.NovelSegment> onPlayFromSegment;
  final ValueChanged<String> onChapterSelected;
  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;
  final VoidCallback onAddChapter;
  final ValueChanged<db.NovelChapter> onEditChapter;
  final ValueChanged<db.NovelChapter> onDeleteChapter;
  final void Function(String theme, double fontSize, double lineHeight)
  onAppearanceChanged;
  final ValueChanged<bool> onOverwriteWhilePlayingChanged;
  final VoidCallback onStop;

  const _ReaderPane({
    required this.project,
    required this.chapter,
    required this.chapters,
    required this.segments,
    required this.allSegments,
    required this.cacheStates,
    required this.requestedPageIndex,
    required this.currentGlobalIndex,
    required this.activePlaybackGlobalIndex,
    required this.readingActive,
    required this.playbackSourceTag,
    required this.generatingSegmentIds,
    required this.importing,
    required this.onPageSelected,
    required this.onPickSegment,
    required this.onPlayFromSegment,
    required this.onChapterSelected,
    required this.onImportFiles,
    required this.onImportFolder,
    required this.onAddChapter,
    required this.onEditChapter,
    required this.onDeleteChapter,
    required this.onAppearanceChanged,
    required this.onOverwriteWhilePlayingChanged,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _readerColors(project.readerTheme);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _buildPages(
          cacheKey: _readerPagesCacheKey(
            constraints: constraints,
            segments: segments,
            fontSize: project.fontSize,
            lineHeight: project.lineHeight,
          ),
          constraints: constraints,
          colors: colors,
          segments: segments,
          fontSize: project.fontSize,
          lineHeight: project.lineHeight,
        );
        final pages = layout.pages;
        final pageCount = math.max(1, pages.length);
        final activePage = _pageForCurrentSegment(layout);
        final pageIndex = (requestedPageIndex ?? activePage)
            .clamp(0, pageCount - 1)
            .toInt();
        final pagePieces = pages.isEmpty
            ? const <_ReaderPagePiece>[]
            : pages[pageIndex];
        final selectedSegment = segments
            .where((segment) => segment.globalIndex == currentGlobalIndex)
            .firstOrNull;
        final chapterIndex = chapter == null
            ? -1
            : chapters.indexWhere((item) => item.id == chapter!.id);

        void goToPage(int index) =>
            onPageSelected(index.clamp(0, pageCount - 1).toInt());

        return KeyboardListener(
          focusNode: FocusNode(),
          autofocus: true,
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                pageIndex > 0) {
              goToPage(pageIndex - 1);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                pageIndex < pageCount - 1) {
              goToPage(pageIndex + 1);
            }
          },
          child: Container(
            color: colors.background,
            child: Column(
              children: [
                _ReaderTopBar(
                  chapterTitle: chapter?.title ?? 'No chapters imported',
                  pageIndex: pageIndex,
                  pageCount: pageCount,
                  colors: colors,
                ),
                Expanded(
                  child: chapter == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).uiUseChaptersBelowToImportTXTImportAFolderOrAddA,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.text.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(46, 18, 46, 8),
                          child: SelectionArea(
                            child: ListView.builder(
                              itemCount: pagePieces.length,
                              itemBuilder: (context, index) {
                                final piece = pagePieces[index];
                                final active =
                                    piece.segment.globalIndex ==
                                    currentGlobalIndex;
                                return _ReaderSegment(
                                  piece: piece,
                                  active: active,
                                  cacheState:
                                      cacheStates[piece.segment.id] ??
                                      _NovelSegmentCacheState.none,
                                  currentCacheColor: _colorFromHex(
                                    project.cacheCurrentColor,
                                    const Color(0xFF2F6B54),
                                  ),
                                  staleCacheColor: _colorFromHex(
                                    project.cacheStaleColor,
                                    const Color(0xFF7A5A2A),
                                  ),
                                  cacheOpacity: project.cacheHighlightOpacity,
                                  colors: colors,
                                  fontSize: project.fontSize,
                                  lineHeight: project.lineHeight,
                                  onTap: () => onPickSegment(piece.segment),
                                  onDoubleTap: () =>
                                      onPlayFromSegment(piece.segment),
                                );
                              },
                            ),
                          ),
                        ),
                ),
                _NovelReaderBottomBar(
                  project: project,
                  colors: colors,
                  chapters: chapters,
                  chapter: chapter,
                  segments: allSegments,
                  generatingSegmentIds: generatingSegmentIds,
                  importing: importing,
                  selectedSegment: selectedSegment,
                  activePlaybackGlobalIndex: activePlaybackGlobalIndex,
                  readingActive: readingActive,
                  playbackSourceTag: playbackSourceTag,
                  onPreviousChapter: chapterIndex <= 0
                      ? null
                      : () => onChapterSelected(chapters[chapterIndex - 1].id),
                  onNextChapter:
                      chapterIndex < 0 || chapterIndex >= chapters.length - 1
                      ? null
                      : () => onChapterSelected(chapters[chapterIndex + 1].id),
                  onPreviousPage: pageIndex == 0
                      ? null
                      : () => goToPage(pageIndex - 1),
                  onNextPage: pageIndex >= pageCount - 1
                      ? null
                      : () => goToPage(pageIndex + 1),
                  onChapterSelected: onChapterSelected,
                  onImportFiles: onImportFiles,
                  onImportFolder: onImportFolder,
                  onAddChapter: onAddChapter,
                  onEditChapter: onEditChapter,
                  onDeleteChapter: onDeleteChapter,
                  onPlaySelected: selectedSegment == null
                      ? null
                      : () => onPlayFromSegment(selectedSegment),
                  onAppearanceChanged: onAppearanceChanged,
                  onOverwriteWhilePlayingChanged:
                      onOverwriteWhilePlayingChanged,
                  onStop: onStop,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _pageForCurrentSegment(_ReaderPagesLayout layout) {
    final current = currentGlobalIndex;
    if (current == null) return 0;
    return layout.pageByGlobalIndex[current] ?? 0;
  }

  _ReaderPagesLayout _buildPages({
    required String cacheKey,
    required BoxConstraints constraints,
    required _ReaderColors colors,
    required List<db.NovelSegment> segments,
    required double fontSize,
    required double lineHeight,
  }) {
    final cached = _readerPagesCache[cacheKey];
    if (cached != null) return cached;

    if (segments.isEmpty ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return const _ReaderPagesLayout(pages: [], pageByGlobalIndex: {});
    }
    final textStyle = TextStyle(
      color: colors.text,
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: 0,
    );
    final contentWidth = math.max(120.0, constraints.maxWidth - 92);
    final pageHeight = math.max(160.0, constraints.maxHeight - 48 - 108 - 34);
    const gap = 12.0;
    const activePaddingAllowance = 16.0;

    final pages = <List<_ReaderPagePiece>>[];
    var currentPage = <_ReaderPagePiece>[];
    var remainingHeight = pageHeight;

    void startPage() {
      if (currentPage.isNotEmpty) pages.add(currentPage);
      currentPage = <_ReaderPagePiece>[];
      remainingHeight = pageHeight;
    }

    for (final segment in segments) {
      var rest = segment.segmentText.trim();
      var continuation = false;
      while (rest.isNotEmpty) {
        final usableHeight = remainingHeight - gap - activePaddingAllowance;
        if (usableHeight <= fontSize * lineHeight * 1.25) {
          startPage();
          continue;
        }

        final fullHeight = _measureTextHeight(rest, textStyle, contentWidth);
        if (fullHeight <= usableHeight) {
          currentPage.add(
            _ReaderPagePiece(
              segment: segment,
              text: rest,
              continuation: continuation,
            ),
          );
          remainingHeight -= fullHeight + gap;
          rest = '';
          continue;
        }

        final fit = _fitTextLength(rest, textStyle, contentWidth, usableHeight);
        if (fit <= 0) {
          startPage();
          continue;
        }
        final splitAt = _readableSplitIndex(rest, fit);
        final pieceText = rest.substring(0, splitAt).trimRight();
        currentPage.add(
          _ReaderPagePiece(
            segment: segment,
            text: pieceText,
            continuation: continuation,
          ),
        );
        startPage();
        rest = rest.substring(splitAt).trimLeft();
        continuation = true;
      }
    }
    if (currentPage.isNotEmpty) pages.add(currentPage);
    final layout = _ReaderPagesLayout(
      pages: pages,
      pageByGlobalIndex: _buildPageIndex(pages),
    );
    _readerPagesCache[cacheKey] = layout;
    if (_readerPagesCache.length > _readerPagesCacheLimit) {
      _readerPagesCache.remove(_readerPagesCache.keys.first);
    }
    return layout;
  }

  Map<int, int> _buildPageIndex(List<List<_ReaderPagePiece>> pages) {
    final pageByGlobalIndex = <int, int>{};
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final piece in pages[pageIndex]) {
        pageByGlobalIndex.putIfAbsent(
          piece.segment.globalIndex,
          () => pageIndex,
        );
      }
    }
    return pageByGlobalIndex;
  }

  String _readerPagesCacheKey({
    required BoxConstraints constraints,
    required List<db.NovelSegment> segments,
    required double fontSize,
    required double lineHeight,
  }) {
    final first = segments.firstOrNull;
    final last = segments.lastOrNull;
    var revision = 0x811c9dc5;
    for (final segment in segments) {
      revision = _combineReaderRevision(revision, segment.id.hashCode);
      revision = _combineReaderRevision(revision, segment.globalIndex);
      revision = _combineReaderRevision(revision, segment.orderIndex);
      revision = _combineReaderRevision(revision, segment.segmentText.length);
      revision = _combineReaderRevision(revision, segment.segmentType.hashCode);
    }
    return [
      constraints.maxWidth.round(),
      constraints.maxHeight.round(),
      fontSize.toStringAsFixed(2),
      lineHeight.toStringAsFixed(2),
      segments.length,
      revision,
      first?.id ?? '',
      first?.globalIndex ?? 0,
      last?.id ?? '',
      last?.globalIndex ?? 0,
    ].join('|');
  }

  int _combineReaderRevision(int hash, int value) {
    return 0x1fffffff & ((hash ^ value) * 16777619);
  }

  double _measureTextHeight(String text, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: width);
    return painter.height;
  }

  int _fitTextLength(
    String text,
    TextStyle style,
    double width,
    double maxHeight,
  ) {
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = ((low + high + 1) / 2).floor();
      final height = _measureTextHeight(text.substring(0, mid), style, width);
      if (height <= maxHeight) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  int _readableSplitIndex(String text, int fit) {
    final safeFit = fit.clamp(1, text.length).toInt();
    if (safeFit >= text.length) return text.length;
    final windowStart = math.max(0, safeFit - 40);
    final head = text.substring(windowStart, safeFit);
    final punct = RegExp(r'[。！？；;.!?，,、]\s*$').firstMatch(head);
    if (punct != null) {
      return windowStart + punct.end;
    }
    return safeFit;
  }

  _ReaderColors _readerColors(String theme) {
    return switch (theme) {
      'paper' => const _ReaderColors(
        background: Color(0xFFF2E8D7),
        surface: Color(0xFFE5D6BD),
        text: Color(0xFF292016),
        muted: Color(0xFF7B6A54),
        active: Color(0xFFFFD88A),
      ),
      'comfort' => const _ReaderColors(
        background: Color(0xFFE8F0DE),
        surface: Color(0xFFD8E5CB),
        text: Color(0xFF253022),
        muted: Color(0xFF66745E),
        active: Color(0xFFCFE8A8),
      ),
      _ => const _ReaderColors(
        background: Color(0xFF101116),
        surface: Color(0xFF1A1B22),
        text: Color(0xFFE8E8EA),
        muted: Color(0xFF888A96),
        active: Color(0xFF373052),
      ),
    };
  }
}
