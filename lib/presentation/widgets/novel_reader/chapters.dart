part of '../../screens/novel_reader_screen.dart';

extension _NovelReaderEditorChapters on _NovelReaderEditorState {
  Future<void> _jumpTo(
    db.NovelProject project,
    db.NovelSegment segment, {
    required bool syncPage,
    bool persistImmediately = true,
  }) async {
    if (mounted) {
      _updateState(() {
        _localCurrentGlobalIndex = segment.globalIndex;
        if (syncPage) {
          _manualChapterId = segment.chapterId;
          _manualPageIndex = null;
        }
      });
    }
    if (persistImmediately) {
      await _persistNovelProgress(project.id, segment.globalIndex, force: true);
    } else {
      unawaited(_persistNovelProgress(project.id, segment.globalIndex));
    }
  }

  Future<void> _persistNovelProgress(
    String projectId,
    int globalIndex, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastPersistedProgressIndex == globalIndex &&
        _lastProgressPersistAt != null &&
        now.difference(_lastProgressPersistAt!) < const Duration(seconds: 8)) {
      return;
    }
    if (!force &&
        _lastProgressPersistAt != null &&
        now.difference(_lastProgressPersistAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastProgressPersistAt = now;
    _lastPersistedProgressIndex = globalIndex;
    final dbx = ref.read(databaseProvider);
    final write = _progressPersistQueue.catchError((_) {}).then((_) async {
      await dbx.markNovelProgress(projectId, globalIndex);
    });
    _progressPersistQueue = write;
    await write;
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
      if (firstSegment.isNotEmpty) {
        _localCurrentGlobalIndex = firstSegment.first.globalIndex;
      }
      _manualChapterId = chapterId;
      _manualPageIndex = 0;
    });
  }

  Future<void> _importFiles(db.NovelProject project) async {
    final picked = await pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'text', 'md', 'epub'],
    );
    if (picked == null) return;
    final files = [
      for (final f in picked.files)
        if (f.path != null) File(f.path!),
    ];
    if (mounted &&
        files.any((f) => p.extension(f.path).toLowerCase() == '.epub')) {
      _snack(AppLocalizations.of(context).novelEpubReserved);
    }
    await _runImport(project, () {
      return ref
          .read(novelImportServiceProvider)
          .importFiles(projectId: project.id, files: files);
    });
  }

  Future<void> _importFolder(db.NovelProject project) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context).novelImportFolderTitle,
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
      _clearReaderPagesCache();
      final report = await run();
      _updateState(() {
        _manualChapterId = null;
        _manualPageIndex = null;
      });
      if (!mounted) return;
      _snack(
        AppLocalizations.of(
          context,
        ).novelImported(report.chapterCount, report.segmentCount),
      );
    } catch (e) {
      if (mounted) _snack(AppLocalizations.of(context).novelImportFailed(e));
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
    _clearReaderPagesCache();
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
    if (mounted) _snack(AppLocalizations.of(context).novelSegmentSaved);
  }

  Future<void> _deleteSegment(
    db.NovelProject project,
    db.NovelSegment segment,
  ) async {
    _stopNovel();
    _clearReaderPagesCache();
    await _deleteAudioPath(segment.audioPath);
    final dbx = ref.read(databaseProvider);
    await dbx.deleteNovelSegment(project.id, segment.id);
    await _syncChapterRawText(project.id, segment.chapterId);
    if (!mounted) return;
    _updateState(() => _manualPageIndex = null);
    _snack(AppLocalizations.of(context).novelSegmentDeleted);
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
    _clearReaderPagesCache();
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
      title: AppLocalizations.of(context).uiDeleteChapter2,
      message: AppLocalizations.of(
        context,
      ).novelDeleteChapterMessage(chapter.title),
      action: AppLocalizations.of(context).uiDelete,
    );
    if (!ok) return;

    _stopNovel();
    _clearReaderPagesCache();
    final dbx = ref.read(databaseProvider);
    final oldSegments = await dbx.getNovelSegmentsForChapter(chapter.id);
    await _deleteSegmentAudioFiles(oldSegments);
    await dbx.deleteNovelChapter(project.id, chapter.id);
    if (!mounted) return;
    _updateState(() {
      if (_manualChapterId == chapter.id) _manualChapterId = null;
      _manualPageIndex = null;
    });
    _snack(AppLocalizations.of(context).novelChapterDeleted);
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
    _clearReaderPagesCache();
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
    _snack(AppLocalizations.of(context).novelDialogueRulesSaved(rebuilt));
  }

  Future<void> _manageTextFilterRules() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _NovelTextFilterRulesDialog(),
    );
    if (changed != true) return;
    ref.invalidate(novelTextFilterRulesProvider);
    if (!mounted) return;
    _snack(AppLocalizations.of(context).novelTextFiltersSaved);
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
            child: Text(AppLocalizations.of(context).uiCancel),
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
