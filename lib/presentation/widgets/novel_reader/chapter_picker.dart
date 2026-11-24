part of '../../screens/novel_reader_screen.dart';

/// Dialogs the bottom bar opens.
extension _NovelReaderBottomBarDialogs on _NovelReaderBottomBar {
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
