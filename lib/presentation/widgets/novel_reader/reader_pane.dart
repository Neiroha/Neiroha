part of '../../screens/novel_reader_screen.dart';

class _ReaderPagePiece {
  final db.NovelSegment segment;
  final String text;
  final bool continuation;

  const _ReaderPagePiece({
    required this.segment,
    required this.text,
    required this.continuation,
  });
}

class _ReaderPageHit {
  final int pageIndex;
  final int textLength;

  const _ReaderPageHit({required this.pageIndex, required this.textLength});
}

enum _NovelSegmentCacheState { none, current, stale }

bool _shouldSkipSegment(db.NovelProject project, db.NovelSegment segment) {
  return project.skipPunctuationOnlySegments &&
      isNovelPunctuationOnly(segment.segmentText);
}

Color _colorFromHex(String raw, Color fallback) {
  final cleaned = raw.trim().replaceFirst('#', '');
  if (cleaned.length != 6 && cleaned.length != 8) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}

String _hexFromColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

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
    final playback = ref.watch(playbackNotifierProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _buildPages(
          constraints: constraints,
          colors: colors,
          segments: segments,
          fontSize: project.fontSize,
          lineHeight: project.lineHeight,
        );
        final pageCount = math.max(1, pages.length);
        final activePage = _pageForCurrentSegment(pages, playback);
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
                          child: Text(
                            'Use Chapters below to import TXT, import a folder, or add a chapter.',
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.text.withValues(alpha: 0.55),
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

  int _pageForCurrentSegment(
    List<List<_ReaderPagePiece>> pages,
    PlaybackState playback,
  ) {
    final current = currentGlobalIndex;
    if (current == null) return 0;
    final hits = <_ReaderPageHit>[];
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final piece in pages[pageIndex]) {
        if (piece.segment.globalIndex == current) {
          hits.add(
            _ReaderPageHit(pageIndex: pageIndex, textLength: piece.text.length),
          );
        }
      }
    }
    if (hits.isEmpty) return 0;
    if (hits.length == 1) return hits.first.pageIndex;
    if (!project.autoTurnPage ||
        playback.sourceTag != playbackSourceTag ||
        playback.duration.inMilliseconds <= 0) {
      return hits.first.pageIndex;
    }

    final totalTextLength = hits.fold<int>(
      0,
      (sum, hit) => sum + math.max(1, hit.textLength),
    );
    final fraction =
        playback.position.inMilliseconds /
        math.max(1, playback.duration.inMilliseconds);
    final target = (totalTextLength * fraction.clamp(0.0, 0.999)).floor();
    var cursor = 0;
    for (final hit in hits) {
      cursor += math.max(1, hit.textLength);
      if (target < cursor) return hit.pageIndex;
    }
    return hits.last.pageIndex;
  }

  List<List<_ReaderPagePiece>> _buildPages({
    required BoxConstraints constraints,
    required _ReaderColors colors,
    required List<db.NovelSegment> segments,
    required double fontSize,
    required double lineHeight,
  }) {
    if (segments.isEmpty ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return const [];
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
    return pages;
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

class _ReaderSegment extends StatelessWidget {
  final _ReaderPagePiece piece;
  final bool active;
  final _NovelSegmentCacheState cacheState;
  final Color currentCacheColor;
  final Color staleCacheColor;
  final double cacheOpacity;
  final _ReaderColors colors;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _ReaderSegment({
    required this.piece,
    required this.active,
    required this.cacheState,
    required this.currentCacheColor,
    required this.staleCacheColor,
    required this.cacheOpacity,
    required this.colors,
    required this.fontSize,
    required this.lineHeight,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = piece.continuation ? '    ${piece.text}' : piece.text;
    final cacheColor = switch (cacheState) {
      _NovelSegmentCacheState.current => currentCacheColor,
      _NovelSegmentCacheState.stale => staleCacheColor,
      _NovelSegmentCacheState.none => null,
    };
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(
          horizontal: active ? 12 : 0,
          vertical: active ? 8 : 0,
        ),
        decoration: BoxDecoration(
          color: active
              ? colors.active.withValues(alpha: 0.9)
              : cacheColor?.withValues(alpha: cacheOpacity.clamp(0.0, 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.text,
            fontSize: fontSize,
            height: lineHeight,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  final String chapterTitle;
  final int pageIndex;
  final int pageCount;
  final _ReaderColors colors;

  const _ReaderTopBar({
    required this.chapterTitle,
    required this.pageIndex,
    required this.pageCount,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.74),
        border: Border(
          bottom: BorderSide(color: colors.muted.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chapterTitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text.withValues(alpha: 0.82),
              ),
            ),
          ),
          Text(
            '${pageIndex + 1} / $pageCount',
            style: TextStyle(
              fontSize: 12,
              color: colors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
