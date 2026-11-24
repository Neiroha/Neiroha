part of '../../screens/novel_reader_screen.dart';

// Page layout cache, text filters and colors for the reader, plus one
// segment of the reader page and the reader's top bar.

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

enum _NovelSegmentCacheState { none, current, stale }

const int _readerPagesCacheLimit = 12;
final Map<String, _ReaderPagesLayout> _readerPagesCache = {};

void _clearReaderPagesCache() {
  _readerPagesCache.clear();
}

class _ReaderPagesLayout {
  final List<List<_ReaderPagePiece>> pages;
  final Map<int, int> pageByGlobalIndex;

  const _ReaderPagesLayout({
    required this.pages,
    required this.pageByGlobalIndex,
  });
}

bool _shouldSkipSegment(db.NovelProject project, db.NovelSegment segment) {
  return project.skipPunctuationOnlySegments &&
      isNovelPunctuationOnly(segment.segmentText);
}

String _filteredNovelTextForTts(
  db.NovelSegment segment,
  List<NovelTextFilterRule> textFilterRules,
) {
  return NovelTextFilterRulesService.applyFilters(
    segment.segmentText,
    textFilterRules,
  ).trim();
}

bool _shouldSkipSegmentForTts(
  db.NovelProject project,
  db.NovelSegment segment,
  List<NovelTextFilterRule> textFilterRules,
) {
  return _shouldSkipSegment(project, segment) ||
      _filteredNovelTextForTts(segment, textFilterRules).isEmpty;
}

bool _hasUsableNovelAudio(db.NovelSegment segment) {
  final path = segment.audioPath;
  return path != null && !segment.missing && File(path).existsSync();
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
