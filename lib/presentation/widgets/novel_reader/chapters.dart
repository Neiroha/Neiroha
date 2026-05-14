part of '../../screens/novel_reader_screen.dart';

extension _NovelReaderEditorChapters on _NovelReaderEditorState {
  Future<void> _jumpTo(
    db.NovelProject project,
    db.NovelSegment segment, {
    required bool syncPage,
  }) async {
    await ref
        .read(databaseProvider)
        .markNovelProgress(project.id, segment.globalIndex);
    if (!syncPage || !mounted) return;
    _updateState(() {
      _manualChapterId = segment.chapterId;
      _manualPageIndex = null;
    });
  }

  Future<void> _selectChapter(
    db.NovelProject project,
    String chapterId,
    List<db.NovelSegment> allSegments,
  ) async {
    final firstSegment =
        allSegments.where((segment) => segment.chapterId == chapterId).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (firstSegment.isNotEmpty) {
      await ref
          .read(databaseProvider)
          .markNovelProgress(project.id, firstSegment.first.globalIndex);
    }
    if (!mounted) return;
    _updateState(() {
      _manualChapterId = chapterId;
      _manualPageIndex = 0;
    });
  }

  Future<void> _importFiles(db.NovelProject project) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'text', 'md', 'epub'],
    );
    if (picked == null) return;
    final files = [
      for (final f in picked.files)
        if (f.path != null) File(f.path!),
    ];
    if (files.any((f) => p.extension(f.path).toLowerCase() == '.epub')) {
      _snack('EPUB import is reserved for the next pass; TXT files were used.');
    }
    await _runImport(project, () {
      return ref
          .read(novelImportServiceProvider)
          .importFiles(projectId: project.id, files: files);
    });
  }

  Future<void> _importFolder(db.NovelProject project) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Import novel folder',
    );
    if (path == null || path.isEmpty) return;
    await _runImport(project, () {
      return ref
          .read(novelImportServiceProvider)
          .importFolder(projectId: project.id, directory: Directory(path));
    });
  }

  Future<void> _runImport(
    db.NovelProject project,
    Future<dynamic> Function() run,
  ) async {
    _updateState(() => _importing = true);
    try {
      _stopNovel();
      final report = await run();
      _updateState(() {
        _manualChapterId = null;
        _manualPageIndex = null;
      });
      _snack(
        'Imported ${report.chapterCount} chapters, ${report.segmentCount} segments.',
      );
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) _updateState(() => _importing = false);
    }
  }

  Future<void> _saveSegmentEdit(
    db.NovelProject project,
    db.NovelSegment segment,
    String text,
  ) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      await _deleteSegment(project, segment);
      return;
    }
    if (cleaned == segment.segmentText) return;

    _stopNovel();
    await _deleteAudioPath(segment.audioPath);
    final dbx = ref.read(databaseProvider);
    await dbx.updateNovelSegment(
      segment.copyWith(
        segmentText: cleaned,
        audioPath: const Value(null),
        audioDuration: const Value(null),
        audioCacheKey: const Value(null),
        error: const Value(null),
        missing: false,
      ),
    );
    await _syncChapterRawText(project.id, segment.chapterId);
    await dbx.updateNovelProject(project.copyWith(updatedAt: DateTime.now()));
    _snack('Segment saved.');
  }

  Future<void> _deleteSegment(
    db.NovelProject project,
    db.NovelSegment segment,
  ) async {
    _stopNovel();
    await _deleteAudioPath(segment.audioPath);
    final dbx = ref.read(databaseProvider);
    await dbx.deleteNovelSegment(project.id, segment.id);
    await _syncChapterRawText(project.id, segment.chapterId);
    if (!mounted) return;
    _updateState(() => _manualPageIndex = null);
    _snack('Segment deleted.');
  }

  Future<void> _showChapterEditorDialog(
    db.NovelProject project, {
    db.NovelChapter? chapter,
  }) async {
    final dbx = ref.read(databaseProvider);
    final currentSegments = chapter == null
        ? const <db.NovelSegment>[]
        : await dbx.getNovelSegmentsForChapter(chapter.id);
    final fallbackText = currentSegments
        .map((segment) => segment.segmentText)
        .join('\n\n');
    if (!mounted) return;

    final result = await showDialog<_ChapterEditResult>(
      context: context,
      builder: (_) => _ChapterEditDialog(
        initialTitle: chapter?.title ?? '',
        initialText: chapter?.rawText.trim().isNotEmpty == true
            ? chapter!.rawText
            : fallbackText,
        isNew: chapter == null,
      ),
    );
    if (result == null) return;

    _stopNovel();
    final dialogueRules = await ref
        .read(novelImportServiceProvider)
        .loadDialogueRules();
    final novelSegments = splitNovelText(
      result.rawText,
      dialogueRules: dialogueRules,
    );
    final chapterId = chapter?.id ?? const Uuid().v4();
    final rows = _segmentRowsForChapter(
      projectId: project.id,
      chapterId: chapterId,
      segments: novelSegments,
    );

    if (chapter == null) {
      final chapters = await dbx.getNovelChapters(project.id);
      await dbx.insertNovelChapterWithSegments(
        projectId: project.id,
        chapter: db.NovelChaptersCompanion(
          id: Value(chapterId),
          projectId: Value(project.id),
          orderIndex: Value(chapters.length),
          title: Value(result.title),
          rawText: Value(result.rawText),
        ),
        segments: rows,
      );
    } else {
      await _deleteSegmentAudioFiles(currentSegments);
      await dbx.replaceNovelChapterText(
        chapter: chapter.copyWith(
          title: result.title,
          sourcePath: const Value(null),
          rawText: result.rawText,
        ),
        segments: rows,
      );
    }

    if (!mounted) return;
    _updateState(() {
      _manualChapterId = chapterId;
      _manualPageIndex = 0;
    });
    _snack(chapter == null ? 'Chapter added.' : 'Chapter updated.');
  }

  List<db.NovelSegmentsCompanion> _segmentRowsForChapter({
    required String projectId,
    required String chapterId,
    required List<NovelTextSegment> segments,
  }) {
    return [
      for (var i = 0; i < segments.length; i++)
        db.NovelSegmentsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(projectId),
          chapterId: Value(chapterId),
          globalIndex: const Value(0),
          orderIndex: Value(i),
          segmentText: Value(segments[i].text),
          segmentType: Value(segments[i].type),
        ),
    ];
  }

  Future<void> _deleteChapter(
    db.NovelProject project,
    db.NovelChapter chapter,
  ) async {
    final ok = await _confirm(
      title: 'Delete chapter?',
      message: 'This removes "${chapter.title}" and its cached audio.',
      action: 'Delete',
    );
    if (!ok) return;

    _stopNovel();
    final dbx = ref.read(databaseProvider);
    final oldSegments = await dbx.getNovelSegmentsForChapter(chapter.id);
    await _deleteSegmentAudioFiles(oldSegments);
    await dbx.deleteNovelChapter(project.id, chapter.id);
    if (!mounted) return;
    _updateState(() {
      if (_manualChapterId == chapter.id) _manualChapterId = null;
      _manualPageIndex = null;
    });
    _snack('Chapter deleted.');
  }

  Future<void> _syncChapterRawText(String projectId, String chapterId) async {
    final dbx = ref.read(databaseProvider);
    final chapters = await dbx.getNovelChapters(projectId);
    final chapter = chapters.where((c) => c.id == chapterId).firstOrNull;
    if (chapter == null) return;
    final segments = await dbx.getNovelSegmentsForChapter(chapterId);
    await dbx.updateNovelChapter(
      chapter.copyWith(
        rawText: segments.map((segment) => segment.segmentText).join('\n\n'),
      ),
    );
  }

  Future<void> _manageDialogueRules(
    db.NovelProject project,
    List<db.NovelSegment> segments,
  ) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _NovelDialogueRulesDialog(),
    );
    if (changed != true) return;

    final rules = await ref.read(novelDialogueRulesServiceProvider).load();
    final dbx = ref.read(databaseProvider);
    final chapters = await dbx.getNovelChapters(project.id);
    var rebuilt = 0;
    for (final chapter in chapters) {
      final currentSegments = segments
          .where((segment) => segment.chapterId == chapter.id)
          .toList();
      final rawText = chapter.rawText.trim().isNotEmpty
          ? chapter.rawText
          : currentSegments.map((segment) => segment.segmentText).join('\n\n');
      final nextSegments = splitNovelText(rawText, dialogueRules: rules);
      await _deleteSegmentAudioFiles(currentSegments);
      await dbx.replaceNovelChapterText(
        chapter: chapter.copyWith(rawText: rawText),
        segments: _segmentRowsForChapter(
          projectId: project.id,
          chapterId: chapter.id,
          segments: nextSegments,
        ),
      );
      rebuilt += nextSegments.length;
    }
    await dbx.updateNovelProject(project.copyWith(updatedAt: DateTime.now()));
    ref.invalidate(novelDialogueRulesProvider);
    if (!mounted) return;
    _snack('Dialogue rules saved; rebuilt $rebuilt segment(s).');
  }

  Future<void> _deleteSegmentAudioFiles(
    Iterable<db.NovelSegment> segments,
  ) async {
    for (final segment in segments) {
      await _deleteAudioPath(segment.audioPath);
    }
  }

  Future<void> _deleteAudioPath(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ChapterEditPane extends StatelessWidget {
  final db.NovelProject project;
  final db.NovelChapter? chapter;
  final List<db.NovelSegment> segments;
  final int? currentGlobalIndex;
  final ValueChanged<db.NovelSegment> onPickSegment;
  final void Function(db.NovelSegment segment, String text) onSaveSegment;
  final ValueChanged<db.NovelSegment> onDeleteSegment;

  const _ChapterEditPane({
    required this.project,
    required this.chapter,
    required this.segments,
    required this.currentGlobalIndex,
    required this.onPickSegment,
    required this.onSaveSegment,
    required this.onDeleteSegment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F14),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    chapter?.title ?? 'No chapter selected',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${segments.length} segments',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: chapter == null
                ? Center(
                    child: Text(
                      'Import or add a chapter to edit novel text.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      return _EditableSegmentRow(
                        key: ValueKey(segment.id),
                        segment: segment,
                        index: index,
                        active: segment.globalIndex == currentGlobalIndex,
                        fontSize: project.fontSize,
                        lineHeight: project.lineHeight,
                        onPick: () => onPickSegment(segment),
                        onSave: (text) => onSaveSegment(segment, text),
                        onDelete: () => onDeleteSegment(segment),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditableSegmentRow extends StatefulWidget {
  final db.NovelSegment segment;
  final int index;
  final bool active;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onPick;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  const _EditableSegmentRow({
    super.key,
    required this.segment,
    required this.index,
    required this.active,
    required this.fontSize,
    required this.lineHeight,
    required this.onPick,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditableSegmentRow> createState() => _EditableSegmentRowState();
}

class _EditableSegmentRowState extends State<_EditableSegmentRow> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.segment.segmentText);
  }

  @override
  void didUpdateWidget(covariant _EditableSegmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.id != widget.segment.id ||
        oldWidget.segment.segmentText != widget.segment.segmentText) {
      _controller.text = widget.segment.segmentText;
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.active
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.surfaceDim,
        border: Border.all(
          color: widget.active
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: InkWell(
                onTap: widget.onPick,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    children: [
                      Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.active
                              ? AppTheme.accentColor
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        widget.segment.segmentType == 'dialogue'
                            ? Icons.record_voice_over_rounded
                            : Icons.notes_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 2,
                maxLines: null,
                style: TextStyle(
                  fontSize: widget.fontSize.clamp(16, 22),
                  height: widget.lineHeight.clamp(1.35, 2.0),
                  letterSpacing: 0,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  final dirty = value.trim() != widget.segment.segmentText;
                  if (dirty != _dirty) setState(() => _dirty = dirty);
                },
              ),
            ),
            const SizedBox(width: 6),
            Column(
              children: [
                IconButton(
                  tooltip: 'Save segment',
                  onPressed: _dirty
                      ? () => widget.onSave(_controller.text)
                      : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete segment',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterEditDialog extends StatefulWidget {
  final String initialTitle;
  final String initialText;
  final bool isNew;

  const _ChapterEditDialog({
    required this.initialTitle,
    required this.initialText,
    required this.isNew,
  });

  @override
  State<_ChapterEditDialog> createState() => _ChapterEditDialogState();
}

class _ChapterEditDialogState extends State<_ChapterEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add Chapter' : 'Edit Chapter'),
      content: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.isNew,
              decoration: const InputDecoration(labelText: 'Chapter title'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _textController,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: 'Chapter text',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _ChapterEditResult(title: title, rawText: _textController.text.trim()),
    );
  }
}

class _ChapterEditResult {
  final String title;
  final String rawText;

  const _ChapterEditResult({required this.title, required this.rawText});
}
