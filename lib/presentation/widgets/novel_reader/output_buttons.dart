part of '../../screens/novel_reader_screen.dart';

Widget _busyIcon(bool busy, IconData icon) => busy
    ? const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : Icon(icon, size: 17);

Widget _buttonLabel(String text) =>
    Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

/// Generate the open chapter or the whole book.
class _NovelGenerateButtons extends StatelessWidget {
  const _NovelGenerateButtons({
    required this.busy,
    required this.onGenerate,
    required this.canGenerateChapter,
  });

  final bool busy;
  final ValueChanged<bool>? onGenerate;
  final bool canGenerateChapter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final generate = onGenerate;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: generate == null || !canGenerateChapter
                ? null
                : () => generate(true),
            icon: _busyIcon(busy, Icons.playlist_add_check_rounded),
            label: _buttonLabel(l10n.novelGenerateChapter),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: generate == null ? null : () => generate(false),
            icon: _busyIcon(busy, Icons.download_done_rounded),
            label: _buttonLabel(l10n.uiGenerateBook),
          ),
        ),
      ],
    );
  }
}

/// Export the open chapter, the whole book, or one file per chapter.
class _NovelExportButtons extends StatelessWidget {
  const _NovelExportButtons({
    required this.busy,
    required this.onExport,
    required this.chapterHasAudio,
  });

  final bool busy;
  final ValueChanged<_NovelExportScope>? onExport;
  final bool chapterHasAudio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final export = onExport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: export == null || !chapterHasAudio
                    ? null
                    : () => export(_NovelExportScope.chapter),
                icon: _busyIcon(busy, Icons.ios_share_rounded),
                label: _buttonLabel(l10n.novelExportChapter),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: export == null
                    ? null
                    : () => export(_NovelExportScope.book),
                icon: _busyIcon(busy, Icons.menu_book_rounded),
                label: _buttonLabel(l10n.uiExportBook),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Tooltip(
          message: l10n.novelExportEachChapterTooltip,
          child: OutlinedButton.icon(
            onPressed: export == null
                ? null
                : () => export(_NovelExportScope.eachChapter),
            icon: _busyIcon(busy, Icons.folder_copy_rounded),
            label: _buttonLabel(l10n.novelExportEachChapter),
          ),
        ),
      ],
    );
  }
}
