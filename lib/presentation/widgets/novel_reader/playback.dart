part of '../../screens/novel_reader_screen.dart';

enum _NovelPlaybackCommand { previous, next, stop }

extension _NovelReaderEditorCache on _NovelReaderEditorState {
  Map<String, _NovelSegmentCacheState> _cacheStatesForSegments(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.VoiceAsset> bankAssets,
    List<db.TtsProvider> providers,
    List<NovelTextFilterRule> textFilterRules,
    String textFilterSignature,
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
          textFilterRules,
          textFilterSignature,
        ),
    };
  }

  _NovelSegmentCacheState _cacheStateForSegment(
    db.NovelProject project,
    db.NovelSegment segment,
    Map<String, db.VoiceAsset> assets,
    Map<String, db.TtsProvider> providers,
    List<NovelTextFilterRule> textFilterRules,
    String textFilterSignature,
  ) {
    if (!_segmentRequiresNovelAudio(project, segment, textFilterRules)) {
      return _NovelSegmentCacheState.none;
    }
    if (!_hasUsableNovelAudio(segment)) return _NovelSegmentCacheState.none;
    final voiceId = _voiceForSegment(project, segment);
    final asset = voiceId == null ? null : assets[voiceId];
    final provider = asset == null ? null : providers[asset.providerId];
    if (asset == null || provider == null) {
      return _NovelSegmentCacheState.stale;
    }
    return _segmentAudioCacheKeyMatches(
          project,
          segment,
          asset,
          provider,
          textFilterSignature,
        )
        ? _NovelSegmentCacheState.current
        : _NovelSegmentCacheState.stale;
  }

  bool _segmentRequiresNovelAudio(
    db.NovelProject project,
    db.NovelSegment segment,
    List<NovelTextFilterRule> textFilterRules,
  ) {
    return !_shouldSkipSegmentForTts(project, segment, textFilterRules);
  }

  bool _segmentAudioIsCurrent(
    db.NovelProject project,
    db.NovelSegment segment,
    Map<String, db.VoiceAsset> assets,
    Map<String, db.TtsProvider> providers,
    List<NovelTextFilterRule> textFilterRules,
    String textFilterSignature,
  ) {
    if (!_segmentRequiresNovelAudio(project, segment, textFilterRules)) {
      return true;
    }
    if (!_hasUsableNovelAudio(segment)) return false;
    final voiceId = _voiceForSegment(project, segment);
    final asset = voiceId == null ? null : assets[voiceId];
    final provider = asset == null ? null : providers[asset.providerId];
    if (asset == null || provider == null) return false;
    return _segmentAudioCacheKeyMatches(
      project,
      segment,
      asset,
      provider,
      textFilterSignature,
    );
  }

  bool _segmentAudioCacheKeyMatches(
    db.NovelProject project,
    db.NovelSegment segment,
    db.VoiceAsset asset,
    db.TtsProvider provider,
    String textFilterSignature,
  ) {
    return segment.audioCacheKey ==
        _cacheKey(
          project,
          segment,
          asset,
          provider,
          textFilterSignature: textFilterSignature,
        );
  }

  bool _novelCacheComplete(
    db.NovelProject project,
    List<db.NovelSegment> segments,
    List<db.VoiceAsset> bankAssets,
    List<db.TtsProvider> providers,
    List<NovelTextFilterRule> textFilterRules,
    String textFilterSignature,
  ) {
    if (segments.isEmpty) return false;
    final assets = {for (final asset in bankAssets) asset.id: asset};
    final providerMap = {
      for (final provider in providers) provider.id: provider,
    };
    return segments.every(
      (segment) => _segmentAudioIsCurrent(
        project,
        segment,
        assets,
        providerMap,
        textFilterRules,
        textFilterSignature,
      ),
    );
  }

  ResolvedNovelVoice _resolvedVoice(
    db.NovelProject project,
    db.NovelSegment segment,
  ) {
    final roles = ref.read(novelRoleSnapshotProvider(project.id)).value;
    if (roles == null) {
      throw StateError('Novel character data is still loading.');
    }
    final members =
        ref.read(bankMembersStreamProvider(project.bankId)).value ?? [];
    return resolveNovelSegmentVoice(
      project: project,
      segment: segment,
      roles: roles,
      availableVoiceIds: members.map((m) => m.voiceAssetId),
    );
  }

  String? _voiceForSegment(db.NovelProject project, db.NovelSegment segment) =>
      _resolvedVoice(project, segment).voiceAssetId;

  TaskProfile? _synthesisProfile(String id) => ref
      .read(novelTaskProfilesProvider(id))
      .value
      ?.where((p) => p.task == ModelTask.synthesis)
      .firstOrNull;

  NovelSynthesisBinding _binding(
    db.NovelProject project,
    db.VoiceAsset asset,
    db.TtsProvider provider,
  ) => NovelSynthesisBinding.resolve(
    asset,
    provider,
    ref.read(ttsProvidersStreamProvider).value ?? [],
    _synthesisProfile(project.id),
  );

  String _cacheKey(
    db.NovelProject project,
    db.NovelSegment segment,
    db.VoiceAsset asset,
    db.TtsProvider provider, {
    String textFilterSignature = '',
  }) {
    final binding = _binding(project, asset, provider);
    return NovelAudioFingerprint.build(
      project: project,
      segment: segment,
      asset: binding.asset,
      provider: binding.provider,
      textFilterSignature: textFilterSignature,
      protocolSignature: binding.profile == null
          ? ''
          : jsonEncode(binding.profile!.toJson()),
      instruction: _resolvedVoice(project, segment).instruction,
    );
  }
}

extension _NovelReaderEditorPlaybackFlow on _NovelReaderEditorState {
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
    final textFilterRules = await ref
        .read(novelTextFilterRulesServiceProvider)
        .load();
    final chapters = await ref
        .read(databaseProvider)
        .getNovelChapters(project.id);
    final chapterMap = {for (final chapter in chapters) chapter.id: chapter};
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
        if (_shouldSkipSegmentForTts(activeProject, segment, textFilterRules)) {
          continue;
        }
        await _jumpTo(
          activeProject,
          segment,
          syncPage: activeProject.autoTurnPage,
          persistImmediately: false,
        );
        if (mounted) {
          _updateState(() => _activePlaybackGlobalIndex = segment.globalIndex);
        }
        final cacheOnly = _cacheOnlyPlayback;
        final forceCache = cacheOnly
            ? false
            : activeProject.overwriteCacheWhilePlaying;
        _prefetchRunId++;
        final commandCompleter = Completer<_NovelPlaybackCommand>();
        _playbackCommandCompleter = commandCompleter;
        final sentenceCancellation = TtsCancelToken();
        _streamGenerationTokens.add(sentenceCancellation);
        void prefetch() {
          if (cacheOnly ||
              runId != _playRunId ||
              sentenceCancellation.isCancelled) {
            return;
          }
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
        }

        final completed =
            _playOneSentence(
              activeProject,
              segment,
              bankAssets,
              sentenceCancellation,
              cacheOnly: cacheOnly,
              force: forceCache,
              subtitle: _segmentSubtitle(
                segment,
                chapterMap[segment.chapterId],
              ),
              onFirstAudio: prefetch,
            ).whenComplete(
              () => _streamGenerationTokens.remove(sentenceCancellation),
            );
        final result = await Future.any<Object?>([
          completed.then<Object?>((_) => null),
          stopCompleter.future.then<Object?>((_) => _NovelPlaybackCommand.stop),
          commandCompleter.future.then<Object?>((command) => command),
        ]);
        if (result != null) sentenceCancellation.cancel();
        if (identical(_playbackCommandCompleter, commandCompleter)) {
          _playbackCommandCompleter = null;
        }
        if (result == _NovelPlaybackCommand.stop) break;
        if (result == _NovelPlaybackCommand.previous) {
          await ref
              .read(playbackNotifierProvider.notifier)
              .stopIfSourceTag(_playbackSourceTag);
          i = math.max(startAt - 1, i - 2);
          continue;
        }
        if (result == _NovelPlaybackCommand.next) {
          await ref
              .read(playbackNotifierProvider.notifier)
              .stopIfSourceTag(_playbackSourceTag);
          continue;
        }
        await _waitForSegmentGap(activeProject, runId, stopCompleter);
      }
    } on TtsCancelledException {
      // A stopped or superseded sentence never advances automatically.
    } catch (e) {
      if (runId == _playRunId && mounted) {
        _snack(AppLocalizations.of(context).novelPlaybackStopped(e));
      }
    } finally {
      if (runId == _playRunId) {
        _stopCompleter = null;
        _playbackCommandCompleter = null;
        if (mounted) {
          _updateState(() {
            _activePlaybackGlobalIndex = null;
          });
        }
        await ref
            .read(playbackNotifierProvider.notifier)
            .stopIfSourceTag(_playbackSourceTag);
      }
    }
  }

  Future<void> _playOneSentence(
    db.NovelProject project,
    db.NovelSegment segment,
    List<db.VoiceAsset> bankAssets,
    TtsCancelToken cancellation, {
    required bool cacheOnly,
    required bool force,
    required String subtitle,
    required void Function() onFirstAudio,
  }) => playNovelSentence(
    ref: ref,
    project: project,
    segment: segment,
    cancellation: cancellation,
    cacheOnly: cacheOnly,
    force: force,
    subtitle: subtitle,
    sourceTag: _playbackSourceTag,
    onFirstAudio: onFirstAudio,
    ensureFile: () =>
        _ensureAudioForSegment(project, segment, bankAssets, force: force),
  );

  Future<void> _waitForSegmentGap(
    db.NovelProject project,
    int runId,
    Completer<void> stopCompleter,
  ) async {
    if (runId != _playRunId || stopCompleter.isCompleted) return;
    final gapMs = (project.playbackGapSeconds.clamp(0.0, 2.0) * 1000).round();
    if (gapMs <= 0) return;
    await Future.any([
      Future.delayed(Duration(milliseconds: gapMs)),
      stopCompleter.future,
    ]);
  }

  void _stopNovel({bool updateUi = true}) {
    _playRunId++;
    _prefetchRunId++;
    for (final token in _streamGenerationTokens.toList()) {
      token.cancel();
    }
    final commandCompleter = _playbackCommandCompleter;
    if (commandCompleter != null && !commandCompleter.isCompleted) {
      commandCompleter.complete(_NovelPlaybackCommand.stop);
    }
    _playbackCommandCompleter = null;
    final completer = _stopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _stopCompleter = null;
    if (updateUi && mounted) {
      _updateState(() => _activePlaybackGlobalIndex = null);
    }
    final localIndex = _localCurrentGlobalIndex;
    if (localIndex != null) {
      unawaited(
        _persistNovelProgress(widget.projectId, localIndex, force: true),
      );
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
    final textFilterRules = await ref
        .read(novelTextFilterRulesServiceProvider)
        .load();
    final candidates = <db.NovelSegment>[];
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
      if (_shouldSkipSegmentForTts(project, segment, textFilterRules)) {
        continue;
      }
      candidates.add(segment);
    }
    if (candidates.isEmpty) return;

    final providers = await ref.read(databaseProvider).getAllProviders();
    if (runId != _playRunId || prefetchRunId != _prefetchRunId) return;

    final taskFactories = [
      for (final segment in candidates)
        () {
          if (runId != _playRunId || prefetchRunId != _prefetchRunId) {
            return Future<String>.value('');
          }
          return _ensureAudioForSegment(
            project,
            segment,
            bankAssets,
            force: forceCache,
          );
        },
    ];
    final failures = <Object>[];
    await _runNovelGenerationWorkers(
      taskFactories,
      workerCount: _novelGenerationWorkerCount(project, bankAssets, providers),
      failures: failures,
      shouldContinue: () =>
          runId == _playRunId && prefetchRunId == _prefetchRunId,
    );
  }
}

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
