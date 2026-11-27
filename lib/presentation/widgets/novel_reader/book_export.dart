part of '../../screens/novel_reader_screen.dart';

/// What an export of the novel covers.
enum _NovelExportScope {
  /// The chapter open in the reader, as one file.
  chapter,

  /// Every chapter in reading order, as one file.
  book,

  /// One file per chapter, written into a folder.
  eachChapter,
}

/// What deciding whether a segment's cache is current needs, loaded once
/// per export.
typedef _NovelExportContext = ({
  List<NovelTextFilterRule> rules,
  String rulesSignature,
  Map<String, db.VoiceAsset> bankAssets,
  Map<String, db.TtsProvider> providers,
});

/// One audio file of an export: the cached clips of its segments in order.
class _NovelExportFile {
  const _NovelExportFile(this.inputs, this.segments);
  final List<String> inputs;
  final List<db.NovelSegment> segments;
}

extension _NovelReaderEditorExport on _NovelReaderEditorState {
  Future<void> _export(
    _NovelExportScope scope,
    db.NovelProject project,
    List<db.NovelSegment> segments, {
    required List<db.NovelChapter> chapters,
    required db.NovelChapter? chapter,
  }) async {
    if (_exporting) return;
    _updateState(() => _exporting = true);
    try {
      switch (scope) {
        case _NovelExportScope.book:
          await _exportOneFile(
            project,
            segments,
            fileStem: PathService.sanitizeSegment(project.name),
          );
        case _NovelExportScope.chapter:
          if (chapter == null) return;
          await _exportOneFile(
            project,
            [
              for (final s in segments)
                if (s.chapterId == chapter.id) s,
            ],
            fileStem: _chapterFileStem(project, chapter, chapters),
            chapter: chapter,
          );
        case _NovelExportScope.eachChapter:
          await _exportEachChapter(project, segments, chapters);
      }
    } finally {
      if (mounted) _updateState(() => _exporting = false);
    }
  }

  Future<_NovelExportContext> _loadExportContext(
    db.NovelProject project,
  ) async {
    final rules = await ref.read(novelTextFilterRulesServiceProvider).load();
    final dbx = ref.read(databaseProvider);
    final members = await dbx.getBankMembers(project.bankId);
    final allAssets = {
      for (final asset in await dbx.getAllVoiceAssets()) asset.id: asset,
    };
    return (
      rules: rules,
      rulesSignature: NovelTextFilterRulesService.signature(rules),
      bankAssets: {
        for (final member in members)
          member.voiceAssetId: ?allAssets[member.voiceAssetId],
      },
      providers: {
        for (final provider in await dbx.getAllProviders())
          provider.id: provider,
      },
    );
  }

  /// The cached clips of [segments] in reading order. Empty when none is
  /// readable; null when a readable segment still needs generating.
  _NovelExportFile? _exportFile(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    _NovelExportContext cache,
  ) {
    final ordered = [...segments]
      ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
    final readable = [
      for (final segment in ordered)
        if (!_shouldSkipSegmentForTts(project, segment, cache.rules)) segment,
    ];
    final inputs = <String>[];
    for (final segment in readable) {
      if (!_segmentAudioIsCurrent(
        project,
        segment,
        cache.bankAssets,
        cache.providers,
        cache.rules,
        cache.rulesSignature,
      )) {
        return null;
      }
      inputs.add(segment.audioPath!);
    }
    return _NovelExportFile(inputs, readable);
  }

  /// Whether FFmpeg can merge here; says why not when it cannot.
  Future<bool> _canMergeAudio() async {
    final l10n = AppLocalizations.of(context);
    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.supportsLocalAudioMuxing) {
      _snack(l10n.uiFFmpegUnavailableOnPlatform(capabilities.platformLabel));
      return false;
    }
    if (!await ref.read(ffmpegServiceProvider).isAvailable()) {
      _snack(l10n.uiFFmpegIsRequiredForExportConfigureItInSettings);
      return false;
    }
    return true;
  }

  /// Gap and de-click fades matching what the reader plays.
  AudioMergeOptions _exportMergeOptions(db.NovelProject project) =>
      AudioMergeOptions(
        gapSeconds: project.playbackGapSeconds,
        fadeInMs: project.playbackGapSeconds > 0 ? 10 : 0,
        fadeOutMs: project.playbackGapSeconds > 0 ? 30 : 0,
      );

  String _chapterFileStem(
    db.NovelProject project,
    db.NovelChapter chapter,
    List<db.NovelChapter> chapters,
  ) {
    final ordered = [...chapters]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final number = (ordered.indexWhere((c) => c.id == chapter.id) + 1)
        .toString()
        .padLeft(ordered.length.toString().length.clamp(2, 4), '0');
    return '${PathService.sanitizeSegment(project.name)}_${number}_'
        '${PathService.sanitizeSegment(chapter.title, fallback: number)}';
  }

  Future<void> _exportOneFile(
    db.NovelProject project,
    List<db.NovelSegment> segments, {
    required String fileStem,
    db.NovelChapter? chapter,
  }) async {
    final l10n = AppLocalizations.of(context);
    final file = _exportFile(
      project,
      segments,
      await _loadExportContext(project),
    );
    if (!mounted) return;
    if (file == null) {
      _snack(
        chapter == null
            ? l10n.uiGenerateFullBookCacheBeforeExporting
            : l10n.novelGenerateChapterBeforeExport(chapter.title),
      );
      return;
    }
    if (file.inputs.isEmpty) {
      _snack(l10n.uiNoReadableSegmentsToExport);
      return;
    }
    if (!await _canMergeAudio() || !mounted) return;
    var outPath = await pickSavePath(
      dialogTitle: l10n.uiExportNovelAudio,
      fileName: '${fileStem}_${PathService.formatTimestamp()}.wav',
      type: FileType.audio,
    );
    if (outPath == null || outPath.isEmpty || !mounted) return;
    if (p.extension(outPath).isEmpty) outPath = '$outPath.wav';
    final outFile = File(outPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    final options = _exportMergeOptions(project);
    if (!options.isPlain) {
      await _mergeWithProgress([(file.inputs, outPath)], options, outPath);
      return;
    }
    await _concatWithProgress(file, outPath);
  }

  /// One file per chapter that has readable text, named by its position.
  Future<void> _exportEachChapter(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.NovelChapter> chapters,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cache = await _loadExportContext(project);
    final ordered = [...chapters]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final files = <(db.NovelChapter, _NovelExportFile)>[];
    for (final chapter in ordered) {
      final file = _exportFile(project, [
        for (final s in segments)
          if (s.chapterId == chapter.id) s,
      ], cache);
      if (file == null) {
        _snack(l10n.novelGenerateChapterBeforeExport(chapter.title));
        return;
      }
      if (file.inputs.isNotEmpty) files.add((chapter, file));
    }
    if (files.isEmpty) {
      _snack(l10n.uiNoReadableSegmentsToExport);
      return;
    }
    if (!await _canMergeAudio() || !mounted) return;
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.novelExportChaptersFolder,
    );
    if (dir == null || dir.isEmpty || !mounted) return;
    final folder = p.join(
      dir,
      '${PathService.sanitizeSegment(project.name)}_'
      '${PathService.formatTimestamp()}',
    );
    await _mergeWithProgress(
      [
        for (final (chapter, file) in files)
          (
            file.inputs,
            p.join(
              folder,
              '${_chapterFileStem(project, chapter, chapters)}.wav',
            ),
          ),
      ],
      _exportMergeOptions(project),
      folder,
    );
  }

  /// Writes each (clips, output) job in turn under one progress dialog.
  Future<void> _mergeWithProgress(
    List<(List<String>, String)> jobs,
    AudioMergeOptions options,
    String shownPath,
  ) async {
    final l10n = AppLocalizations.of(context);
    final merger = ref.read(audioMergeServiceProvider);
    Object? failure;
    final completed = await runTaskWithProgress(
      context: context,
      taskLabel: l10n.uiExportingNovelAudio,
      task: (report, cancelled) async {
        try {
          for (var i = 0; i < jobs.length; i++) {
            final (inputs, outPath) = jobs[i];
            await merger.merge(
              inputs: inputs,
              outputPath: outPath,
              options: options,
              encoderArgs: LoudnessNormalizer.encoderArgsFor(
                p.extension(outPath).toLowerCase(),
              ),
              onProgress: (v) => report((i + v) / jobs.length),
              isCancelled: cancelled,
            );
          }
        } on AudioMergeCancelled {
          // Reported through the return value.
        } catch (e) {
          failure = e;
        }
      },
    );
    if (!mounted) return;
    if (failure != null) {
      _snack(l10n.uiExportFailed(failure!));
    } else if (!completed) {
      _snack(l10n.uiExportCancelled);
    } else {
      await showExportSuccessDialog(context: context, filePath: shownPath);
    }
  }

  /// Joins the clips without re-rendering them (no gap, no fades).
  Future<void> _concatWithProgress(
    _NovelExportFile file,
    String outPath,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ffmpeg = ref.read(ffmpegServiceProvider);
    final listFile = File(
      p.join(
        File(outPath).parent.path,
        '.novel_concat_${DateTime.now().microsecondsSinceEpoch}.txt',
      ),
    );
    try {
      await listFile.writeAsString(_concatFileList(file.inputs), flush: true);
      final ffmpegPath = await ffmpeg.resolvePath();
      if (!mounted) return;
      final result = await runFfmpegWithProgress(
        context: context,
        ffmpegPath: ffmpegPath,
        args: [
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
        ],
        totalDurationMs: _totalDurationMs(file.segments),
        taskLabel: l10n.uiExportingNovelAudio,
      );
      if (!mounted) return;
      if (result.success) {
        await showExportSuccessDialog(context: context, filePath: outPath);
      } else if (result.cancelled) {
        _snack(l10n.uiExportCancelled);
      } else {
        _snack(l10n.uiExportFailed(result.stderrTail));
      }
    } finally {
      try {
        if (await listFile.exists()) await listFile.delete();
      } catch (_) {}
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

  String _segmentSubtitle(db.NovelSegment segment, [db.NovelChapter? chapter]) {
    final l10n = AppLocalizations.of(context);
    final prefix = segment.segmentType == 'dialogue'
        ? l10n.novelDialogue
        : l10n.novelNarrator;
    final chapterTitle = chapter?.title.trim();
    final segmentLabel =
        '$prefix · ${l10n.novelSegmentLabel(segment.globalIndex + 1)}';
    if (chapterTitle == null || chapterTitle.isEmpty) return segmentLabel;
    return '$chapterTitle · $segmentLabel';
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
}
