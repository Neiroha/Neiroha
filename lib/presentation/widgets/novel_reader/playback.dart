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
      protocolSignature: binding.profileSignature,
      chainSignature:
          ref.read(voiceChainSignaturesProvider).value?[asset.id] ?? '',
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
