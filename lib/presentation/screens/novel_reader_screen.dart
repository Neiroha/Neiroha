import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/novel_dialogue_rules_service.dart';
import 'package:neiroha/data/storage/novel_import_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/export_progress.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Lightweight novel reader: import text chapters, read them comfortably, and
/// cache generated TTS locally per novel project.
class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({super.key});

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) return _buildProjectListScreen();
    return _NovelReaderEditor(
      key: ValueKey(_selectedProjectId),
      projectId: _selectedProjectId!,
      onClose: () => setState(() => _selectedProjectId = null),
    );
  }

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(novelProjectsStreamProvider);
    return Column(
      children: [
        _NovelProjectHeader(onCreate: _createProject),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) => ProjectCardGrid(
              emptyLabel: 'No novel projects yet',
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.menu_book_rounded,
                    subtitle: _readerPreview(p),
                  ),
              ],
              onOpen: (id) => setState(() => _selectedProjectId = id),
              onDelete: (id) {
                ref.read(databaseProvider).deleteNovelProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  String? _readerPreview(db.NovelProject project) {
    final voice = project.narratorVoiceAssetId == null ? 'No narrator' : null;
    if (voice != null) return voice;
    return 'Reading position ${project.currentGlobalIndex + 1}';
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    if (banks.isEmpty) {
      _snack('Create a Voice Bank first.');
      return;
    }
    final result = await showDialog<_CreateNovelResult>(
      context: context,
      builder: (_) => _CreateNovelDialog(banks: banks),
    );
    if (result == null) return;

    final dbx = ref.read(databaseProvider);
    final members = await dbx.getBankMembers(result.bankId);
    final narratorId = members.isNotEmpty ? members.first.voiceAssetId : null;
    final dialogueId = members.length > 1
        ? members[1].voiceAssetId
        : narratorId;
    final id = const Uuid().v4();
    final now = DateTime.now();
    await dbx.insertNovelProject(
      db.NovelProjectsCompanion(
        id: Value(id),
        name: Value(result.name),
        bankId: Value(result.bankId),
        narratorVoiceAssetId: Value(narratorId),
        dialogueVoiceAssetId: Value(dialogueId),
        readerTheme: const Value('dark'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (mounted) setState(() => _selectedProjectId = id);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

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
  Future<void> _ttsSerialTail = Future<void>.value();

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

  Map<String, _NovelSegmentCacheState> _cacheStatesForSegments(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.VoiceAsset> bankAssets,
    List<db.TtsProvider> providers,
  ) {
    final assets = {for (final asset in bankAssets) asset.id: asset};
    final providerMap = {
      for (final provider in providers) provider.id: provider,
    };
    return {
      for (final segment in segments)
        segment.id: _cacheStateForSegment(
          project,
          segment,
          assets,
          providerMap,
        ),
    };
  }

  _NovelSegmentCacheState _cacheStateForSegment(
    db.NovelProject project,
    db.NovelSegment segment,
    Map<String, db.VoiceAsset> assets,
    Map<String, db.TtsProvider> providers,
  ) {
    if (segment.audioPath == null || segment.missing) {
      return _NovelSegmentCacheState.none;
    }
    if (_shouldSkipSegment(project, segment)) {
      return _NovelSegmentCacheState.none;
    }
    final voiceId = _voiceForSegment(project, segment);
    final asset = voiceId == null ? null : assets[voiceId];
    final provider = asset == null ? null : providers[asset.providerId];
    if (asset == null || provider == null) {
      return _NovelSegmentCacheState.stale;
    }
    final currentKey = _cacheKey(project, segment, asset, provider);
    return segment.audioCacheKey == currentKey
        ? _NovelSegmentCacheState.current
        : _NovelSegmentCacheState.stale;
  }

  Future<void> _jumpTo(
    db.NovelProject project,
    db.NovelSegment segment, {
    required bool syncPage,
  }) async {
    await ref
        .read(databaseProvider)
        .markNovelProgress(project.id, segment.globalIndex);
    if (!syncPage || !mounted) return;
    setState(() {
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
    setState(() {
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
    setState(() => _importing = true);
    try {
      _stopNovel();
      final report = await run();
      setState(() {
        _manualChapterId = null;
        _manualPageIndex = null;
      });
      _snack(
        'Imported ${report.chapterCount} chapters, ${report.segmentCount} segments.',
      );
    } catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
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
    setState(() => _manualPageIndex = null);
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
    setState(() {
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
    setState(() {
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

  Future<void> _playFromSegment(
    db.NovelProject project,
    db.NovelSegment start,
    List<db.NovelSegment> allSegments,
    List<db.VoiceAsset> bankAssets,
  ) async {
    _stopNovel();
    final runId = ++_playRunId;
    final stopCompleter = Completer<void>();
    _stopCompleter = stopCompleter;

    final ordered = [...allSegments]
      ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
    final startAt = ordered.indexWhere(
      (segment) => segment.globalIndex >= start.globalIndex,
    );
    if (startAt == -1) {
      _stopCompleter = null;
      return;
    }

    try {
      for (var i = startAt; i < ordered.length; i++) {
        if (runId != _playRunId || stopCompleter.isCompleted) break;
        final segment = ordered[i];
        final activeProject =
            await ref.read(databaseProvider).getNovelProjectById(project.id) ??
            project;
        if (!activeProject.autoAdvanceChapters &&
            segment.chapterId != start.chapterId) {
          break;
        }
        if (_shouldSkipSegment(activeProject, segment)) {
          continue;
        }
        await _jumpTo(
          activeProject,
          segment,
          syncPage: activeProject.autoTurnPage,
        );
        if (mounted) {
          setState(() => _activePlaybackGlobalIndex = segment.globalIndex);
        }
        final forceCache = activeProject.overwriteCacheWhilePlaying;
        _prefetchRunId++;
        final audioPath = await _ensureAudioForSegment(
          activeProject,
          segment,
          bankAssets,
          force: forceCache,
        );
        if (runId != _playRunId || stopCompleter.isCompleted) break;
        final completed = ref.read(audioPlayerProvider).onPlayerComplete.first;
        await ref
            .read(playbackNotifierProvider.notifier)
            .load(
              audioPath,
              segment.segmentText,
              subtitle: _segmentSubtitle(segment),
              sourceTag: _playbackSourceTag,
            );
        unawaited(
          _prefetchAfter(
            activeProject,
            ordered,
            i,
            bankAssets,
            runId,
            prefetchRunId: _prefetchRunId,
            forceCache: forceCache,
          ),
        );
        await Future.any([completed, stopCompleter.future]);
      }
    } catch (e) {
      if (runId == _playRunId) _snack('Playback stopped: $e');
    } finally {
      if (runId == _playRunId && mounted) {
        setState(() {
          _stopCompleter = null;
          _activePlaybackGlobalIndex = null;
        });
      }
    }
  }

  void _stopNovel({bool updateUi = true}) {
    _playRunId++;
    _prefetchRunId++;
    final completer = _stopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _stopCompleter = null;
    if (updateUi && mounted) {
      setState(() => _activePlaybackGlobalIndex = null);
    }
    unawaited(
      ref
          .read(playbackNotifierProvider.notifier)
          .stopIfSourceTag(_playbackSourceTag),
    );
  }

  Future<void> _prefetchAfter(
    db.NovelProject project,
    List<db.NovelSegment> ordered,
    int index,
    List<db.VoiceAsset> bankAssets,
    int runId, {
    required int prefetchRunId,
    required bool forceCache,
  }) async {
    final prefetchCount = project.prefetchSegments.clamp(0, 20).toInt();
    if (prefetchCount <= 0) return;
    for (
      var i = index + 1;
      i < ordered.length && i <= index + prefetchCount;
      i++
    ) {
      if (runId != _playRunId || prefetchRunId != _prefetchRunId) break;
      final segment = ordered[i];
      if (!project.autoAdvanceChapters &&
          segment.chapterId != ordered[index].chapterId) {
        break;
      }
      if (!forceCache && segment.audioPath != null && !segment.missing) {
        continue;
      }
      if (_shouldSkipSegment(project, segment)) continue;
      try {
        await _ensureAudioForSegment(
          project,
          segment,
          bankAssets,
          force: forceCache,
        );
      } catch (_) {}
      if (runId != _playRunId || prefetchRunId != _prefetchRunId) break;
    }
  }

  Future<void> _generateAllMissing(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.VoiceAsset> bankAssets, {
    required bool force,
  }) async {
    if (_generatingAll) return;
    setState(() => _generatingAll = true);
    final ordered = [...segments]
      ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
    try {
      for (final segment in ordered) {
        if (_shouldSkipSegment(project, segment)) continue;
        await _ensureAudioForSegment(
          project,
          segment,
          bankAssets,
          force: force,
        );
      }
      _snack(force ? 'Novel cache overwritten.' : 'Novel cache completed.');
    } catch (e) {
      _snack('Generate all stopped: $e');
    } finally {
      if (mounted) setState(() => _generatingAll = false);
    }
  }

  Future<String> _ensureAudioForSegment(
    db.NovelProject project,
    db.NovelSegment segment,
    List<db.VoiceAsset> bankAssets, {
    bool force = false,
  }) async {
    if (_shouldSkipSegment(project, segment)) {
      throw StateError('Skipped punctuation-only segment.');
    }
    final dbx = ref.read(databaseProvider);
    final providers = await dbx.getAllProviders();
    final assetMap = {for (final a in bankAssets) a.id: a};
    final voiceId = _voiceForSegment(project, segment);
    final asset = voiceId == null ? null : assetMap[voiceId];
    if (asset == null) {
      throw StateError('Select narrator/dialogue voices first.');
    }
    final provider = providers
        .where((p) => p.id == asset.providerId)
        .firstOrNull;
    if (provider == null) throw StateError('Provider not found for voice.');

    if (!force &&
        segment.audioPath != null &&
        !segment.missing &&
        File(segment.audioPath!).existsSync()) {
      return segment.audioPath!;
    }

    final taskKey = force ? '${segment.id}:force' : segment.id;
    final existingTask = _audioTasks[taskKey];
    if (existingTask != null) return existingTask;

    final task = _runSerializedNovelTts(
      () => _generateAudioForSegment(
        project: project,
        segment: segment,
        asset: asset,
        provider: provider,
        force: force,
      ),
    );
    _audioTasks[taskKey] = task;
    try {
      return await task;
    } finally {
      if (identical(_audioTasks[taskKey], task)) {
        _audioTasks.remove(taskKey);
      }
    }
  }

  Future<String> _generateAudioForSegment({
    required db.NovelProject project,
    required db.NovelSegment segment,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    required bool force,
  }) async {
    final dbx = ref.read(databaseProvider);
    final fresh = (await dbx.getNovelSegments(
      project.id,
    )).where((s) => s.id == segment.id).firstOrNull;
    final activeSegment = fresh ?? segment;
    final activeCacheKey = _cacheKey(project, activeSegment, asset, provider);
    if (!force &&
        activeSegment.audioPath != null &&
        !activeSegment.missing &&
        File(activeSegment.audioPath!).existsSync()) {
      return activeSegment.audioPath!;
    }

    if (mounted) setState(() => _generatingSegmentIds.add(segment.id));
    try {
      final slug = await ref
          .read(storageServiceProvider)
          .ensureNovelProjectSlug(project.id);
      final outDir = await PathService.instance.novelReaderAudioDir(slug);
      final chunks = _ttsChunksForSegment(project, activeSegment.segmentText);
      final adapter = createAdapter(provider, modelName: asset.modelName);
      final fileBase =
          'seg_${activeSegment.globalIndex}_${_stableHash(activeCacheKey)}';
      final result = chunks.length == 1
          ? await _synthesizeNovelChunk(
              adapter: adapter,
              text: chunks.first,
              asset: asset,
              provider: provider,
            )
          : await _synthesizeSlicedSegment(
              adapter: adapter,
              chunks: chunks,
              asset: asset,
              provider: provider,
              outDir: outDir,
              fileBase: fileBase,
            );
      final oldAudioPath = activeSegment.audioPath;
      final filePath = await _writeNovelCacheAudio(
        result: result,
        outDir: outDir,
        fileBase: fileBase,
        force: force,
      );
      final durationSec = await measureAudioDuration(filePath);
      await dbx.updateNovelSegment(
        activeSegment.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          audioCacheKey: Value(activeCacheKey),
          error: const Value(null),
          missing: false,
        ),
      );
      if (force && oldAudioPath != null && oldAudioPath != filePath) {
        await _deleteAudioPath(oldAudioPath);
      }
      return filePath;
    } catch (e) {
      await dbx.updateNovelSegment(
        activeSegment.copyWith(error: Value(e.toString())),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _generatingSegmentIds.remove(segment.id));
    }
  }

  Future<String> _writeNovelCacheAudio({
    required TtsResult result,
    required Directory outDir,
    required String fileBase,
    required bool force,
  }) async {
    final mp3Path = p.join(outDir.path, '$fileBase.mp3');
    final mp3File = File(mp3Path);
    if (_isMp3ContentType(result.contentType)) {
      if (force || !await mp3File.exists()) {
        await mp3File.writeAsBytes(result.audioBytes, flush: true);
      }
      return mp3Path;
    }

    final sourceExt = _extensionForContentType(result.contentType);
    final tempPath = p.join(outDir.path, '.$fileBase.source$sourceExt');
    final tempFile = File(tempPath);
    try {
      await tempFile.writeAsBytes(result.audioBytes, flush: true);
      if (await _convertAudioToMp3(tempPath, mp3Path)) {
        return mp3Path;
      }
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }

    final fallbackPath = p.join(outDir.path, '$fileBase$sourceExt');
    final fallbackFile = File(fallbackPath);
    if (force || !await fallbackFile.exists()) {
      await fallbackFile.writeAsBytes(result.audioBytes, flush: true);
    }
    return fallbackPath;
  }

  Future<bool> _convertAudioToMp3(String inputPath, String outputPath) async {
    final ffmpeg = ref.read(ffmpegServiceProvider);
    if (!await ffmpeg.isAvailable()) return false;
    final ffmpegPath = await ffmpeg.resolvePath();
    try {
      final result = await Process.run(ffmpegPath, [
        '-y',
        '-v',
        'error',
        '-i',
        inputPath,
        '-c:a',
        'libmp3lame',
        '-q:a',
        '4',
        outputPath,
      ]);
      return result.exitCode == 0 && await File(outputPath).exists();
    } catch (_) {
      return false;
    }
  }

  bool _isMp3ContentType(String contentType) {
    final lower = contentType.toLowerCase();
    return lower.contains('mpeg') || lower.contains('mp3');
  }

  Future<T> _runSerializedNovelTts<T>(Future<T> Function() task) {
    final previous = _ttsSerialTail;
    final completer = Completer<T>();
    _ttsSerialTail = previous.catchError((_) {}).then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<TtsResult> _synthesizeNovelChunk({
    required TtsAdapter adapter,
    required String text,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    bool preferWav = false,
  }) {
    return adapter
        .synthesize(
          TtsRequest(
            text: text,
            voice: asset.presetVoiceName ?? asset.name,
            speed: asset.speed,
            responseFormat: preferWav ? 'wav' : 'mp3',
            textLang: provider.adapterType == 'gptSovits'
                ? asset.modelName
                : null,
            presetVoiceName: asset.presetVoiceName,
            voiceInstruction: _supportsVoiceInstruction(asset, provider)
                ? asset.voiceInstruction
                : null,
            refAudioPath: asset.refAudioPath,
            promptText: asset.promptText,
            promptLang: asset.promptLang,
          ),
        )
        .timeout(
          const Duration(minutes: 5),
          onTimeout: () =>
              throw TimeoutException('Novel TTS request timed out.'),
        );
  }

  Future<TtsResult> _synthesizeSlicedSegment({
    required TtsAdapter adapter,
    required List<String> chunks,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    required Directory outDir,
    required String fileBase,
  }) async {
    final results = <TtsResult>[];
    for (final chunk in chunks) {
      results.add(
        await _synthesizeNovelChunk(
          adapter: adapter,
          text: chunk,
          asset: asset,
          provider: provider,
          preferWav: true,
        ),
      );
    }

    final wavBytes = _concatWavResults(results);
    if (wavBytes != null) {
      return TtsResult(audioBytes: wavBytes, contentType: 'audio/wav');
    }

    final ffmpeg = ref.read(ffmpegServiceProvider);
    if (!await ffmpeg.isAvailable()) {
      throw StateError(
        'Long segment was sliced, but the returned audio is not WAV. '
        'Configure FFmpeg in Settings to merge sliced audio.',
      );
    }

    final tempFiles = <File>[];
    try {
      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        final ext = _extensionForContentType(result.contentType);
        final file = File(p.join(outDir.path, '.$fileBase.slice_$i$ext'));
        await file.writeAsBytes(result.audioBytes, flush: true);
        tempFiles.add(file);
      }
      final output = p.join(outDir.path, '$fileBase.wav');
      final ok = await ffmpeg.concatAudio(
        inputPaths: [for (final file in tempFiles) file.path],
        outputPath: output,
        reEncode: true,
      );
      if (!ok) throw StateError('FFmpeg failed to merge sliced audio.');
      return TtsResult(
        audioBytes: await File(output).readAsBytes(),
        contentType: 'audio/wav',
      );
    } finally {
      for (final file in tempFiles) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  List<String> _ttsChunksForSegment(db.NovelProject project, String text) {
    if (!project.autoSliceLongSegments) return [text];
    final maxChars = project.maxSliceChars.clamp(20, 80).toInt();
    if (text.length <= maxChars) return [text];
    return project.sliceOnlyAtPunctuation
        ? _splitTextForTtsAfterPunctuation(text, maxChars)
        : _splitTextForTts(text, maxChars);
  }

  List<String> _splitTextForTts(String text, int maxChars) {
    final chunks = <String>[];
    var rest = text.trim();
    while (rest.length > maxChars) {
      final boundary = _bestTtsBoundary(rest, maxChars);
      chunks.add(rest.substring(0, boundary).trim());
      rest = rest.substring(boundary).trimLeft();
    }
    if (rest.isNotEmpty) chunks.add(rest);
    return chunks.where((chunk) => chunk.isNotEmpty).toList(growable: false);
  }

  List<String> _splitTextForTtsAfterPunctuation(String text, int maxChars) {
    final chunks = <String>[];
    final hardLimit = math.max(maxChars + 20, (maxChars * 2.2).round());
    final parts = RegExp(
      r'[\s\S]*?(?:[。！？；;.!?，,、][”"’』」）\]\】]?|$)',
    ).allMatches(text.trim()).map((match) => match.group(0) ?? '');
    var current = '';

    for (final part in parts) {
      if (part.isEmpty) continue;
      current += part;
      final endsAtPunctuation = RegExp(
        r'[。！？；;.!?，,、][”"’』」）\]\】]?$',
      ).hasMatch(current);
      if (current.length >= maxChars && endsAtPunctuation) {
        chunks.add(current.trim());
        current = '';
        continue;
      }
      while (current.length >= hardLimit) {
        final splitAt = _bestTtsBoundary(current, maxChars);
        chunks.add(current.substring(0, splitAt).trim());
        current = current.substring(splitAt).trimLeft();
      }
    }

    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks.where((chunk) => chunk.isNotEmpty).toList(growable: false);
  }

  int _bestTtsBoundary(String text, int maxChars) {
    final limit = math.min(maxChars, text.length);
    final min = math.max(1, (maxChars * 0.55).round());
    for (final pattern in const [
      r'[。！？；;.!?][”"’』」）\]\】]?',
      r'[，,、]',
      r'\s+',
    ]) {
      final matches = RegExp(pattern).allMatches(text.substring(0, limit));
      final candidates = matches
          .map((m) => m.end)
          .where((idx) => idx >= min)
          .toList();
      if (candidates.isNotEmpty) return candidates.last;
    }
    return limit;
  }

  Uint8List? _concatWavResults(List<TtsResult> results) {
    final wavs = <_WavParts>[];
    for (final result in results) {
      final parts = _parseWav(result.audioBytes);
      if (parts == null) return null;
      wavs.add(parts);
    }
    if (wavs.isEmpty) return null;
    final fmt = wavs.first.fmt;
    if (wavs.any((w) => !_sameBytes(w.fmt, fmt))) return null;
    final dataLength = wavs.fold<int>(0, (sum, w) => sum + w.data.length);
    final builder = BytesBuilder(copy: false);
    _writeAscii(builder, 'RIFF');
    _writeUint32(builder, 4 + (8 + fmt.length) + (8 + dataLength));
    _writeAscii(builder, 'WAVE');
    _writeAscii(builder, 'fmt ');
    _writeUint32(builder, fmt.length);
    builder.add(fmt);
    _writeAscii(builder, 'data');
    _writeUint32(builder, dataLength);
    for (final wav in wavs) {
      builder.add(wav.data);
    }
    return builder.takeBytes();
  }

  _WavParts? _parseWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      return null;
    }
    Uint8List? fmt;
    Uint8List? data;
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      final start = offset + 8;
      final end = math.min(start + size, bytes.length);
      if (id == 'fmt ') {
        fmt = Uint8List.fromList(bytes.sublist(start, end));
      } else if (id == 'data') {
        data = Uint8List.fromList(bytes.sublist(start, end));
      }
      offset = start + size + (size.isOdd ? 1 : 0);
    }
    if (fmt == null || data == null) return null;
    return _WavParts(fmt: fmt, data: data);
  }

  bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _writeAscii(BytesBuilder builder, String text) {
    builder.add(text.codeUnits);
  }

  void _writeUint32(BytesBuilder builder, int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(bytes.buffer.asUint8List());
  }

  String? _voiceForSegment(db.NovelProject project, db.NovelSegment segment) {
    if (segment.segmentType == 'dialogue') {
      return project.dialogueVoiceAssetId ?? project.narratorVoiceAssetId;
    }
    return project.narratorVoiceAssetId ?? project.dialogueVoiceAssetId;
  }

  String _cacheKey(
    db.NovelProject project,
    db.NovelSegment segment,
    db.VoiceAsset asset,
    db.TtsProvider provider,
  ) {
    return [
      'novel-v1',
      segment.segmentText,
      segment.segmentType,
      project.autoSliceLongSegments ? 'slice-on' : 'slice-off',
      project.sliceOnlyAtPunctuation ? 'punct-on' : 'punct-off',
      project.maxSliceChars.toString(),
      asset.id,
      asset.name,
      asset.modelName ?? '',
      asset.presetVoiceName ?? '',
      asset.speed.toStringAsFixed(3),
      asset.voiceInstruction ?? '',
      asset.refAudioPath ?? '',
      asset.promptText ?? '',
      asset.promptLang ?? '',
      provider.id,
      provider.adapterType,
      provider.defaultModelName,
    ].join('\u001F');
  }

  bool _supportsVoiceInstruction(db.VoiceAsset asset, db.TtsProvider provider) {
    return switch (provider.adapterType) {
      'chatCompletionsTts' => _isMimoTtsModel(asset, provider),
      'cosyvoice' => true,
      'voxcpm2Native' => true,
      'geminiTts' => true,
      _ => false,
    };
  }

  bool _isMimoTtsModel(db.VoiceAsset asset, db.TtsProvider provider) {
    final model = (asset.modelName ?? provider.defaultModelName).toLowerCase();
    return provider.adapterType == 'chatCompletionsTts' &&
        model.contains('mimo') &&
        (model.contains('tts') ||
            model.contains('voiceclone') ||
            model.contains('voicedesign'));
  }

  Future<void> _exportBook(
    db.NovelProject project,
    List<db.NovelSegment> segments,
  ) async {
    setState(() => _exporting = true);
    try {
      final ordered = [...segments]
        ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
      final inputs = [
        for (final segment in ordered)
          if (segment.audioPath != null &&
              !segment.missing &&
              File(segment.audioPath!).existsSync())
            segment.audioPath!,
      ];
      if (inputs.length != ordered.length) {
        _snack('Generate the full book cache before exporting.');
        return;
      }
      final ffmpeg = ref.read(ffmpegServiceProvider);
      if (!await ffmpeg.isAvailable()) {
        _snack('FFmpeg is required for export - configure it in Settings.');
        return;
      }
      var outPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export novel audio',
        fileName:
            '${PathService.sanitizeSegment(project.name)}_${PathService.formatTimestamp()}.wav',
        type: FileType.audio,
      );
      if (outPath == null || outPath.isEmpty) return;
      if (p.extension(outPath).isEmpty) outPath = '$outPath.wav';
      final outFile = File(outPath);
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }
      final listFile = File(
        p.join(
          outFile.parent.path,
          '.novel_concat_${DateTime.now().microsecondsSinceEpoch}.txt',
        ),
      );
      try {
        await listFile.writeAsString(_concatFileList(inputs), flush: true);
        final args = [
          '-y',
          '-f',
          'concat',
          '-safe',
          '0',
          '-i',
          listFile.path,
          '-c:a',
          _audioCodecForExt(p.extension(outPath).toLowerCase()),
          outPath,
        ];
        final ffmpegPath = await ffmpeg.resolvePath();
        if (!mounted) return;
        final result = await runFfmpegWithProgress(
          context: context,
          ffmpegPath: ffmpegPath,
          args: args,
          totalDurationMs: _totalDurationMs(ordered),
          taskLabel: 'Exporting novel audio...',
        );
        if (!mounted) return;
        if (result.success) {
          await showExportSuccessDialog(context: context, filePath: outPath);
        } else if (result.cancelled) {
          _snack('Export cancelled.');
        } else {
          _snack('Export failed: ${result.stderrTail}');
        }
      } finally {
        try {
          if (await listFile.exists()) await listFile.delete();
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  int _totalDurationMs(List<db.NovelSegment> segments) {
    var total = 0;
    for (final segment in segments) {
      if (segment.audioDuration == null || segment.audioPath == null) continue;
      total += (segment.audioDuration! * 1000).round();
    }
    return total;
  }

  String _segmentSubtitle(db.NovelSegment segment) {
    final prefix = segment.segmentType == 'dialogue' ? 'Dialogue' : 'Narrator';
    return '$prefix · Segment ${segment.globalIndex + 1}';
  }

  String _extensionForContentType(String contentType) {
    final lower = contentType.toLowerCase();
    if (lower.contains('wav')) return '.wav';
    if (lower.contains('ogg')) return '.ogg';
    if (lower.contains('opus')) return '.opus';
    if (lower.contains('flac')) return '.flac';
    return '.mp3';
  }

  String _concatFileList(List<String> inputPaths) {
    final buffer = StringBuffer();
    for (final raw in inputPaths) {
      final normalized = raw.replaceAll('\\', '/').replaceAll("'", r"'\''");
      buffer.writeln("file '$normalized'");
    }
    return buffer.toString();
  }

  String _audioCodecForExt(String ext) {
    switch (ext) {
      case '.mp3':
        return 'libmp3lame';
      case '.ogg':
      case '.opus':
        return 'libopus';
      case '.flac':
        return 'flac';
      case '.wav':
      default:
        return 'pcm_s16le';
    }
  }

  String _stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                const SizedBox(width: 8),
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
                const SizedBox(width: 14),
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
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
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
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                _ReaderControlButton(
                  tooltip: 'Previous chapter',
                  icon: Icons.skip_previous_rounded,
                  onPressed: onPreviousChapter,
                ),
                _ReaderControlButton(
                  tooltip: 'Previous page',
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
                const SizedBox(width: 6),
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
                  tooltip: 'Reader appearance',
                  icon: _themeIcon(project.readerTheme),
                  onPressed: () => _openAppearance(context),
                ),
                _ReaderControlButton(
                  tooltip: 'Next page',
                  icon: Icons.chevron_right_rounded,
                  onPressed: onNextPage,
                ),
                _ReaderControlButton(
                  tooltip: 'Next chapter',
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
          const Expanded(child: Text('Chapters')),
          IconButton(
            tooltip: 'Import TXT files',
            onPressed: importing
                ? null
                : () => Navigator.pop(
                    context,
                    const _ReaderChapterPickerResult(
                      action: _ReaderChapterPickerAction.importFiles,
                    ),
                  ),
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_rounded),
          ),
          IconButton(
            tooltip: 'Import folder',
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
            tooltip: 'Add chapter',
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
                  'Import TXT files, import a folder, or add a chapter.',
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
                          const Padding(
                            padding: EdgeInsets.only(top: 8, right: 2),
                            child: Icon(Icons.check_rounded),
                          ),
                        IconButton(
                          tooltip: 'Edit chapter',
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
                          tooltip: 'Delete chapter',
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
          child: const Text('Cancel'),
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

class _NovelDialogueRulesDialog extends ConsumerStatefulWidget {
  const _NovelDialogueRulesDialog();

  @override
  ConsumerState<_NovelDialogueRulesDialog> createState() =>
      _NovelDialogueRulesDialogState();
}

class _NovelDialogueRulesDialogState
    extends ConsumerState<_NovelDialogueRulesDialog> {
  List<NovelDialogueRule> _rules = const [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await ref.read(novelDialogueRulesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(novelDialogueRulesServiceProvider).save(_rules);
    ref.invalidate(novelDialogueRulesProvider);
    _dirty = false;
  }

  Future<void> _addRule() async {
    final rule = await _showNovelDialogueRuleEditor(context);
    if (rule == null) return;
    setState(() {
      _rules = [..._rules, rule];
      _dirty = true;
    });
  }

  Future<void> _editRule(NovelDialogueRule rule) async {
    final next = await _showNovelDialogueRuleEditor(context, existing: rule);
    if (next == null) return;
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) next else item,
      ];
      _dirty = true;
    });
  }

  void _deleteRule(NovelDialogueRule rule) {
    if (rule.builtIn) return;
    setState(() {
      _rules = _rules.where((item) => item.id != rule.id).toList();
      _dirty = true;
    });
  }

  void _toggleRule(NovelDialogueRule rule, bool enabled) {
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) item.copyWith(enabled: enabled) else item,
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Dialogue Rules')),
          IconButton(
            tooltip: 'Add rule',
            onPressed: _loading ? null : _addRule,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 430,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                itemCount: _rules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  return _DialogueRuleTile(
                    rule: rule,
                    onToggle: (enabled) => _toggleRule(rule, enabled),
                    onEdit: rule.builtIn ? null : () => _editRule(rule),
                    onDelete: rule.builtIn ? null : () => _deleteRule(rule),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () async {
            if (_dirty) await _save();
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(_dirty ? 'Save & Apply' : 'Apply'),
        ),
      ],
    );
  }
}

class _DialogueRuleTile extends StatelessWidget {
  final NovelDialogueRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DialogueRuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Switch(value: rule.enabled, onChanged: onToggle),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (rule.builtIn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'built-in',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accentColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rule.pattern,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded, size: 16),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_rounded, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

Future<NovelDialogueRule?> _showNovelDialogueRuleEditor(
  BuildContext context, {
  NovelDialogueRule? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final patternCtrl = TextEditingController(text: existing?.pattern ?? '');
  String? error;

  return showDialog<NovelDialogueRule>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(
            existing == null ? 'New Dialogue Rule' : 'Edit Dialogue Rule',
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: patternCtrl,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Regex pattern',
                    helperText: r'Examples: “[\s\S]*?”   /   "[\s\S]*?"',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pattern = patternCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = 'Name is required');
                  return;
                }
                if (pattern.isEmpty) {
                  setDialogState(() => error = 'Pattern is required');
                  return;
                }
                try {
                  RegExp(pattern, multiLine: true, dotAll: true);
                } on FormatException catch (e) {
                  setDialogState(() => error = 'Invalid regex: ${e.message}');
                  return;
                }
                Navigator.pop(
                  ctx,
                  NovelDialogueRule(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    pattern: pattern,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    nameCtrl.dispose();
    patternCtrl.dispose();
  });
}

class _ReaderAppearanceDialog extends StatefulWidget {
  final db.NovelProject project;

  const _ReaderAppearanceDialog({required this.project});

  @override
  State<_ReaderAppearanceDialog> createState() =>
      _ReaderAppearanceDialogState();
}

class _ReaderAppearanceDialogState extends State<_ReaderAppearanceDialog> {
  late String _theme;
  late double _fontSize;
  late double _lineHeight;

  @override
  void initState() {
    super.initState();
    _theme = widget.project.readerTheme;
    _fontSize = widget.project.fontSize;
    _lineHeight = widget.project.lineHeight;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reader Appearance'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'comfort',
                  icon: Icon(Icons.eco_rounded, size: 16),
                  label: Text('Comfort'),
                ),
                ButtonSegment(
                  value: 'paper',
                  icon: Icon(Icons.article_rounded, size: 16),
                  label: Text('Paper'),
                ),
                ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode_rounded, size: 16),
                  label: Text('Dark'),
                ),
              ],
              selected: {_theme},
              onSelectionChanged: (values) =>
                  setState(() => _theme = values.first),
            ),
            const SizedBox(height: 18),
            _SliderSetting(
              label: 'Font',
              value: _fontSize,
              min: 16,
              max: 28,
              divisions: 12,
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            _SliderSetting(
              label: 'Line',
              value: _lineHeight,
              min: 1.4,
              max: 2.1,
              divisions: 7,
              onChanged: (value) => setState(() => _lineHeight = value),
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
          onPressed: () => Navigator.pop(
            context,
            _ReaderAppearanceResult(
              theme: _theme,
              fontSize: _fontSize,
              lineHeight: _lineHeight,
            ),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _ReaderAppearanceResult {
  final String theme;
  final double fontSize;
  final double lineHeight;

  const _ReaderAppearanceResult({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
  });
}

class _NovelSettingsPane extends StatelessWidget {
  final db.NovelProject project;
  final List<db.VoiceAsset> bankAssets;
  final List<db.NovelSegment> segments;
  final Set<String> generatingSegmentIds;
  final bool importing;
  final bool exporting;
  final bool hasAudio;
  final bool generatingAll;
  final bool editing;
  final ValueChanged<String?> onNarratorChanged;
  final ValueChanged<String?> onDialogueChanged;
  final ValueChanged<bool> onAutoTurnPageChanged;
  final ValueChanged<bool> onAutoAdvanceChaptersChanged;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<bool> onAutoSliceChanged;
  final ValueChanged<bool> onSliceOnlyAtPunctuationChanged;
  final ValueChanged<int> onMaxSliceCharsChanged;
  final ValueChanged<int> onPrefetchSegmentsChanged;
  final ValueChanged<bool> onOverwriteWhilePlayingChanged;
  final ValueChanged<bool> onSkipPunctuationOnlyChanged;
  final VoidCallback onManageDialogueRules;
  final ValueChanged<String> onCacheCurrentColorChanged;
  final ValueChanged<String> onCacheStaleColorChanged;
  final ValueChanged<double> onCacheHighlightOpacityChanged;
  final VoidCallback? onGenerateAll;
  final VoidCallback? onExport;

  const _NovelSettingsPane({
    required this.project,
    required this.bankAssets,
    required this.segments,
    required this.generatingSegmentIds,
    required this.importing,
    required this.exporting,
    required this.hasAudio,
    required this.generatingAll,
    required this.editing,
    required this.onNarratorChanged,
    required this.onDialogueChanged,
    required this.onAutoTurnPageChanged,
    required this.onAutoAdvanceChaptersChanged,
    required this.onEditingChanged,
    required this.onAutoSliceChanged,
    required this.onSliceOnlyAtPunctuationChanged,
    required this.onMaxSliceCharsChanged,
    required this.onPrefetchSegmentsChanged,
    required this.onOverwriteWhilePlayingChanged,
    required this.onSkipPunctuationOnlyChanged,
    required this.onManageDialogueRules,
    required this.onCacheCurrentColorChanged,
    required this.onCacheStaleColorChanged,
    required this.onCacheHighlightOpacityChanged,
    required this.onGenerateAll,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceDim,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          _PanelTitle('VOICES'),
          _VoiceDropdown(
            value: project.narratorVoiceAssetId,
            assets: bankAssets,
            label: 'Narrator',
            onChanged: onNarratorChanged,
          ),
          const SizedBox(height: 10),
          _VoiceDropdown(
            value: project.dialogueVoiceAssetId,
            assets: bankAssets,
            label: 'Dialogue',
            onChanged: onDialogueChanged,
          ),
          const SizedBox(height: 18),
          _PanelTitle('EDIT'),
          _CompactSwitch(
            label: 'Edit novel text',
            value: editing,
            onChanged: onEditingChanged,
          ),
          const SizedBox(height: 18),
          _PanelTitle('CACHE'),
          _CompactSwitch(
            label: 'Auto slice long segments',
            value: project.autoSliceLongSegments,
            onChanged: onAutoSliceChanged,
          ),
          _CompactSwitch(
            label: 'Slice after punctuation',
            value: project.sliceOnlyAtPunctuation,
            onChanged: onSliceOnlyAtPunctuationChanged,
          ),
          _SliderSetting(
            label: 'Slice',
            value: project.maxSliceChars.clamp(20, 80).toDouble(),
            min: 20,
            max: 80,
            divisions: 12,
            valueLabel: '${project.maxSliceChars.clamp(20, 80)}',
            onChanged: (v) => onMaxSliceCharsChanged(v.round()),
          ),
          const SizedBox(height: 6),
          _ColorSetting(
            label: 'Current',
            value: project.cacheCurrentColor,
            fallback: const Color(0xFF2F6B54),
            onChanged: onCacheCurrentColorChanged,
          ),
          _ColorSetting(
            label: 'Changed',
            value: project.cacheStaleColor,
            fallback: const Color(0xFF7A5A2A),
            onChanged: onCacheStaleColorChanged,
          ),
          _SliderSetting(
            label: 'Alpha',
            value: project.cacheHighlightOpacity.clamp(0.02, 0.24).toDouble(),
            min: 0.02,
            max: 0.24,
            divisions: 11,
            valueLabel:
                '${(project.cacheHighlightOpacity.clamp(0.02, 0.24) * 100).round()}%',
            onChanged: onCacheHighlightOpacityChanged,
          ),
          _CompactSwitch(
            label: 'Overwrite while reading',
            value: project.overwriteCacheWhilePlaying,
            onChanged: onOverwriteWhilePlayingChanged,
          ),
          _CompactSwitch(
            label: 'Skip punctuation-only text',
            value: project.skipPunctuationOnlySegments,
            onChanged: onSkipPunctuationOnlyChanged,
          ),
          OutlinedButton.icon(
            onPressed: onManageDialogueRules,
            icon: const Icon(Icons.rule_rounded, size: 17),
            label: const Text('Dialogue Rules'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: generatingAll || importing ? null : onGenerateAll,
            icon: generatingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done_rounded, size: 17),
            label: const Text('Generate Book'),
          ),
          const SizedBox(height: 8),
          Text(
            generatingSegmentIds.isEmpty
                ? 'Idle'
                : 'Generating ${generatingSegmentIds.length} segment(s)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 18),
          _PanelTitle('OUTPUT'),
          OutlinedButton.icon(
            onPressed: hasAudio && !exporting ? onExport : null,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 17),
            label: const Text('Export Book'),
          ),
          const SizedBox(height: 18),
          _PanelTitle('PLAYBACK'),
          _CompactSwitch(
            label: 'Auto turn page while playing',
            value: project.autoTurnPage,
            onChanged: onAutoTurnPageChanged,
          ),
          _CompactSwitch(
            label: 'Auto switch chapters while playing',
            value: project.autoAdvanceChapters,
            onChanged: onAutoAdvanceChaptersChanged,
          ),
          _SliderSetting(
            label: 'Ahead',
            value: project.prefetchSegments.clamp(0, 20).toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            valueLabel: '${project.prefetchSegments.clamp(0, 20)}',
            onChanged: (v) => onPrefetchSegmentsChanged(v.round()),
          ),
        ],
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

class _NovelEditorBar extends StatelessWidget {
  final db.NovelProject project;
  final VoidCallback onBack;

  const _NovelEditorBar({required this.project, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to novels',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.menu_book_rounded,
            color: AppTheme.accentColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NovelProjectHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const _NovelProjectHeader({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          const Text(
            'Novel Reader',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Novel'),
          ),
        ],
      ),
    );
  }
}

class _CreateNovelDialog extends StatefulWidget {
  final List<db.VoiceBank> banks;

  const _CreateNovelDialog({required this.banks});

  @override
  State<_CreateNovelDialog> createState() => _CreateNovelDialogState();
}

class _CreateNovelDialogState extends State<_CreateNovelDialog> {
  final _nameController = TextEditingController();
  late String _bankId;

  @override
  void initState() {
    super.initState();
    _bankId = widget.banks
        .firstWhere((bank) => bank.isActive, orElse: () => widget.banks.first)
        .id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Novel'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Project name'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bankId,
              decoration: const InputDecoration(labelText: 'Voice bank'),
              items: [
                for (final bank in widget.banks)
                  DropdownMenuItem(value: bank.id, child: Text(bank.name)),
              ],
              onChanged: (id) {
                if (id != null) setState(() => _bankId = id);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, _CreateNovelResult(name: name, bankId: _bankId));
  }
}

class _CreateNovelResult {
  final String name;
  final String bankId;

  const _CreateNovelResult({required this.name, required this.bankId});
}

class _VoiceDropdown extends StatelessWidget {
  final String? value;
  final List<db.VoiceAsset> assets;
  final String label;
  final ValueChanged<String?> onChanged;

  const _VoiceDropdown({
    required this.value,
    required this.assets,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = assets.map((asset) => asset.id).toSet();
    final effectiveValue = value != null && ids.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: InputDecoration(labelText: label, isDense: true),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('-- Unassigned --'),
        ),
        for (final asset in assets)
          DropdownMenuItem(
            value: asset.id,
            child: Text(asset.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ColorSetting extends StatelessWidget {
  final String label;
  final String value;
  final Color fallback;
  final ValueChanged<String> onChanged;

  const _ColorSetting({
    required this.label,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(value, fallback);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDialog<String>(
                  context: context,
                  builder: (_) => _ColorPickerDialog(
                    initialHex: _hexFromColor(color),
                    fallback: fallback,
                  ),
                );
                if (picked != null) onChanged(picked);
              },
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _hexFromColor(color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final String initialHex;
  final Color fallback;

  const _ColorPickerDialog({required this.initialHex, required this.fallback});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _controller;

  static const _palette = [
    Color(0xFF2F6B54),
    Color(0xFF3E6B8F),
    Color(0xFF6A5BA8),
    Color(0xFF7A5A2A),
    Color(0xFF8C4B4B),
    Color(0xFF62656F),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialHex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _colorFromHex(_controller.text, widget.fallback);
    return AlertDialog(
      title: const Text('Cache Highlight Color'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _palette)
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        setState(() => _controller.text = _hexFromColor(color)),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == color
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Hex color'),
              onChanged: (_) => setState(() {}),
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
          onPressed: () => Navigator.pop(
            context,
            _hexFromColor(_colorFromHex(_controller.text, widget.fallback)),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            valueLabel ?? value.toStringAsFixed(label == 'Font' ? 0 : 1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String label;

  const _PanelTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _ReaderColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color active;

  const _ReaderColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.active,
  });
}

class _WavParts {
  final Uint8List fmt;
  final Uint8List data;

  const _WavParts({required this.fmt, required this.data});
}
