part of '../../screens/novel_reader_screen.dart';

extension _NovelReaderEditorExport on _NovelReaderEditorState {
  Future<void> _exportBook(
    db.NovelProject project,
    List<db.NovelSegment> segments,
  ) async {
    _updateState(() => _exporting = true);
    final l10n = AppLocalizations.of(context);
    try {
      final ordered = [...segments]
        ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
      final textFilterRules = await ref
          .read(novelTextFilterRulesServiceProvider)
          .load();
      final textFilterSignature = NovelTextFilterRulesService.signature(
        textFilterRules,
      );
      final dbx = ref.read(databaseProvider);
      final members = await dbx.getBankMembers(project.bankId);
      final allAssets = await dbx.getAllVoiceAssets();
      final providers = await dbx.getAllProviders();
      final allAssetMap = {for (final asset in allAssets) asset.id: asset};
      final bankAssets = {
        for (final member in members)
          if (allAssetMap[member.voiceAssetId] != null)
            member.voiceAssetId: allAssetMap[member.voiceAssetId]!,
      };
      final providerMap = {
        for (final provider in providers) provider.id: provider,
      };
      final requiredSegments = [
        for (final segment in ordered)
          if (!_shouldSkipSegmentForTts(project, segment, textFilterRules))
            segment,
      ];
      final inputs = [
        for (final segment in requiredSegments)
          if (_segmentAudioIsCurrent(
            project,
            segment,
            bankAssets,
            providerMap,
            textFilterRules,
            textFilterSignature,
          ))
            segment.audioPath!,
      ];
      if (requiredSegments.isEmpty) {
        _snack(l10n.uiNoReadableSegmentsToExport);
        return;
      }
      if (inputs.length != requiredSegments.length) {
        _snack(l10n.uiGenerateFullBookCacheBeforeExporting);
        return;
      }
      final capabilities = ref.read(platformCapabilitiesProvider);
      if (!capabilities.supportsLocalAudioMuxing) {
        _snack(l10n.uiFFmpegUnavailableOnPlatform(capabilities.platformLabel));
        return;
      }
      final ffmpeg = ref.read(ffmpegServiceProvider);
      if (!await ffmpeg.isAvailable()) {
        _snack(l10n.uiFFmpegIsRequiredForExportConfigureItInSettings);
        return;
      }
      var outPath = await pickSavePath(
        dialogTitle: l10n.uiExportNovelAudio,
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
      // Match what the reader plays: the same gap between segments, with
      // short de-click fades at every cut.
      final options = AudioMergeOptions(
        gapSeconds: project.playbackGapSeconds,
        fadeInMs: project.playbackGapSeconds > 0 ? 10 : 0,
        fadeOutMs: project.playbackGapSeconds > 0 ? 30 : 0,
      );
      if (!options.isPlain) {
        await _exportBookWithSpacing(inputs, outPath, options);
        return;
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
          totalDurationMs: _totalDurationMs(requiredSegments),
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
    } finally {
      if (mounted) _updateState(() => _exporting = false);
    }
  }

  Future<void> _exportBookWithSpacing(
    List<String> inputs,
    String outPath,
    AudioMergeOptions options,
  ) async {
    final l10n = AppLocalizations.of(context);
    final merger = ref.read(audioMergeServiceProvider);
    Object? failure;
    final completed = await runTaskWithProgress(
      context: context,
      taskLabel: l10n.uiExportingNovelAudio,
      task: (report, cancelled) async {
        try {
          await merger.merge(
            inputs: inputs,
            outputPath: outPath,
            options: options,
            encoderArgs: LoudnessNormalizer.encoderArgsFor(
              p.extension(outPath).toLowerCase(),
            ),
            onProgress: report,
            isCancelled: cancelled,
          );
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
      await showExportSuccessDialog(context: context, filePath: outPath);
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
