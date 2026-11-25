part of '../../screens/novel_reader_screen.dart';

extension _NovelReaderEditorGeneration on _NovelReaderEditorState {
  Future<void> _generateAllMissing(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.VoiceAsset> bankAssets, {
    required bool force,
  }) async {
    if (_generatingAll) return;
    _updateState(() => _generatingAll = true);
    final l10n = AppLocalizations.of(context);
    final failures = <Object>[];
    try {
      final ordered = [...segments]
        ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
      final textFilterRules = await ref
          .read(novelTextFilterRulesServiceProvider)
          .load();
      final providers = await ref.read(databaseProvider).getAllProviders();
      final taskFactories = [
        for (final segment in ordered)
          if (!_shouldSkipSegmentForTts(project, segment, textFilterRules))
            () => _ensureAudioForSegment(
              project,
              segment,
              bankAssets,
              force: force,
            ),
      ];
      await _runNovelGenerationWorkers(
        taskFactories,
        workerCount: _novelGenerationWorkerCount(
          project,
          bankAssets,
          providers,
        ),
        failures: failures,
      );
      if (failures.isEmpty) {
        _snack(
          force ? l10n.uiNovelCacheOverwritten : l10n.uiNovelCacheCompleted,
        );
      } else {
        _snack(l10n.uiNovelCacheCompletedWithFailures(failures.length));
      }
    } catch (e) {
      _snack(l10n.uiGenerateAllStopped(e));
    } finally {
      if (mounted) _updateState(() => _generatingAll = false);
    }
  }

  Future<void> _runNovelGenerationWorkers(
    List<Future<String> Function()> taskFactories, {
    required int workerCount,
    required List<Object> failures,
    bool Function()? shouldContinue,
  }) async {
    if (taskFactories.isEmpty) return;
    var nextIndex = 0;
    final workers = math.min(workerCount, taskFactories.length);

    Future<void> worker() async {
      while (true) {
        if (shouldContinue?.call() == false) return;
        final current = nextIndex++;
        if (current >= taskFactories.length) return;
        try {
          await taskFactories[current]();
        } catch (e) {
          failures.add(e);
        }
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  }

  int _novelGenerationWorkerCount(
    db.NovelProject project,
    List<db.VoiceAsset> bankAssets,
    List<db.TtsProvider> providers,
  ) {
    final assetMap = {for (final asset in bankAssets) asset.id: asset};
    final providerMap = {
      for (final provider in providers) provider.id: provider,
    };
    final voiceIds = <String>{
      if (project.narratorVoiceAssetId != null) project.narratorVoiceAssetId!,
      if (project.dialogueVoiceAssetId != null) project.dialogueVoiceAssetId!,
    };

    var total = 0;
    for (final voiceId in voiceIds) {
      final asset = assetMap[voiceId];
      if (asset == null) continue;
      final provider = providerMap[asset.providerId];
      if (provider == null) continue;
      total += provider.maxConcurrency.clamp(1, 64).toInt();
    }
    return total.clamp(1, 32).toInt();
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
    final streamService = ref.read(novelStreamingServiceProvider);
    final plan = await streamService.prepare(project, segment);
    if (plan.canStream) {
      if (!force && plan.cachedPath != null) return plan.cachedPath!;
      final cancellation = TtsCancelToken();
      _streamGenerationTokens.add(cancellation);
      if (mounted) _updateState(() => _generatingSegmentIds.add(segment.id));
      try {
        return (await streamService.generate(
          plan,
          cancellation: cancellation,
        )).audioPath;
      } finally {
        _streamGenerationTokens.remove(cancellation);
        if (mounted) {
          _updateState(() => _generatingSegmentIds.remove(segment.id));
        }
      }
    }
    final dbx = ref.read(databaseProvider);
    final providers = await dbx.getAllProviders();
    final assetMap = {for (final a in bankAssets) a.id: a};
    final voiceId = _voiceForSegment(project, segment);
    final baseAsset = voiceId == null ? null : assetMap[voiceId];
    final direction = _resolvedVoice(project, segment).instruction;
    var asset = baseAsset == null || direction == null
        ? baseAsset
        : baseAsset.copyWith(voiceInstruction: Value(direction));
    if (asset == null) {
      throw StateError('Select narrator/dialogue voices first.');
    }
    var provider = providers
        .where((p) => p.id == asset!.providerId)
        .firstOrNull;
    if (provider == null) throw StateError('Provider not found for voice.');
    final binding = _binding(project, asset, provider);
    asset = binding.asset;
    provider = binding.provider;
    if (mounted) {
      warnIfVoiceHealthFailedOnce(context: context, ref: ref, asset: asset);
    }

    final textFilterRules = await ref
        .read(novelTextFilterRulesServiceProvider)
        .load();
    final textFilterSignature = NovelTextFilterRulesService.signature(
      textFilterRules,
    );
    final cacheKey = _cacheKey(
      project,
      segment,
      asset,
      provider,
      textFilterSignature: textFilterSignature,
    );
    if (!force &&
        segment.audioPath != null &&
        !segment.missing &&
        segment.audioCacheKey == cacheKey &&
        File(segment.audioPath!).existsSync()) {
      return segment.audioPath!;
    }

    final taskKey =
        '${segment.id}:${force ? 'force' : 'normal'}:${_stableHash(cacheKey)}';
    final existingTask = _audioTasks[taskKey];
    if (existingTask != null) return existingTask;

    final task = _generateAudioForSegment(
      project: project,
      segment: segment,
      asset: asset,
      provider: provider,
      force: force,
      textFilterRules: textFilterRules,
      textFilterSignature: textFilterSignature,
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
    required List<NovelTextFilterRule> textFilterRules,
    required String textFilterSignature,
  }) async {
    final dbx = ref.read(databaseProvider);
    final fresh = (await dbx.getNovelSegments(
      project.id,
    )).where((s) => s.id == segment.id).firstOrNull;
    final activeSegment = fresh ?? segment;
    final activeCacheKey = _cacheKey(
      project,
      activeSegment,
      asset,
      provider,
      textFilterSignature: textFilterSignature,
    );
    if (!force &&
        activeSegment.audioPath != null &&
        !activeSegment.missing &&
        activeSegment.audioCacheKey == activeCacheKey &&
        File(activeSegment.audioPath!).existsSync()) {
      return activeSegment.audioPath!;
    }

    if (mounted) _updateState(() => _generatingSegmentIds.add(segment.id));
    try {
      final slug = await ref
          .read(storageServiceProvider)
          .ensureNovelProjectSlug(project.id);
      final outDir = await PathService.instance.novelReaderAudioDir(slug);
      final filteredText = _filteredNovelTextForTts(
        activeSegment,
        textFilterRules,
      );
      if (filteredText.isEmpty) {
        throw StateError(
          'Segment ${activeSegment.globalIndex + 1} is empty after text filters.',
        );
      }
      final chunks = _ttsChunksForSegment(project, filteredText);
      final fileBase =
          'seg_${activeSegment.globalIndex}_${_stableHash(activeCacheKey)}';
      final taskLabel =
          'Segment ${activeSegment.globalIndex + 1}: $filteredText';
      final result = chunks.length == 1
          ? await _synthesizeNovelChunk(
              text: chunks.first,
              asset: asset,
              provider: provider,
              taskLabel: taskLabel,
            )
          : await _synthesizeSlicedSegment(
              chunks: chunks,
              asset: asset,
              provider: provider,
              outDir: outDir,
              fileBase: fileBase,
              taskLabel: taskLabel,
            );
      final oldAudioPath = activeSegment.audioPath;
      final filePath = await NovelCacheFileWriter(
        ref.read(ffmpegServiceProvider),
        ref.read(platformCapabilitiesProvider),
      ).write(result: result, outDir: outDir, fileBase: fileBase, force: force);
      await ref
          .read(autoLoudnessServiceProvider)
          .normalizeGenerated(
            enabled: project.autoNormalizeLoudness,
            path: filePath,
            bankId: project.bankId,
            voiceAssetId: asset.id,
          );
      final durationSec = _stopCompleter == null
          ? await measureAudioDuration(filePath)
          : null;
      await dbx.completeNovelAudio(
        activeSegment,
        path: filePath,
        cacheKey: activeCacheKey,
        duration: durationSec,
      );
      if (force && oldAudioPath != null && oldAudioPath != filePath) {
        await _deleteAudioPath(oldAudioPath);
      }
      return filePath;
    } catch (e) {
      await dbx.recordNovelAudioError(activeSegment, e.toString());
      rethrow;
    } finally {
      if (mounted) _updateState(() => _generatingSegmentIds.remove(segment.id));
    }
  }
}

extension _NovelReaderEditorSynthesis on _NovelReaderEditorState {
  Future<TtsResult> _synthesizeNovelChunk({
    required String text,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    bool preferWav = false,
    String? taskLabel,
  }) {
    return ref
        .read(ttsQueueServiceProvider)
        .synthesize(
          provider: provider,
          modelName: asset.modelName,
          source: 'Novel Reader',
          label: taskLabel ?? text,
          request: TtsRequest(
            text: text,
            voice: asset.presetVoiceName ?? asset.name,
            voiceAssetId: asset.id,
            speed: asset.speed,
            responseFormat: preferWav ? 'wav' : 'mp3',
            textLang: provider.adapterType == 'gptSovits'
                ? asset.modelName
                : null,
            presetVoiceName: asset.presetVoiceName,
            voiceInstruction:
                VoiceCapabilities.supportsVoiceInstruction(asset, provider)
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
    required List<String> chunks,
    required db.VoiceAsset asset,
    required db.TtsProvider provider,
    required Directory outDir,
    required String fileBase,
    required String taskLabel,
  }) async {
    final results = await Future.wait([
      for (var i = 0; i < chunks.length; i++)
        _synthesizeNovelChunk(
          text: chunks[i],
          asset: asset,
          provider: provider,
          preferWav: true,
          taskLabel: '$taskLabel (${i + 1}/${chunks.length})',
        ),
    ]);

    final wavBytes = NovelAudioTools.concatWavResults(results);
    if (wavBytes != null) {
      return TtsResult(audioBytes: wavBytes, contentType: 'audio/wav');
    }

    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.supportsLocalAudioMuxing) {
      throw StateError(
        'Long segment slicing needs local audio muxing, which is not '
        'available on ${capabilities.platformLabel}.',
      );
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
}

extension _NovelReaderAudioHelpers on _NovelReaderEditorState {
  List<String> _ttsChunksForSegment(db.NovelProject project, String text) =>
      NovelAudioTools.chunks(
        text,
        autoSlice: project.autoSliceLongSegments,
        maxSliceChars: project.maxSliceChars,
        punctuationOnly: project.sliceOnlyAtPunctuation,
      );
}
