part of '../../screens/novel_reader_screen.dart';

extension _NovelReaderEditorCache on _NovelReaderEditorState {
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
          _updateState(() => _activePlaybackGlobalIndex = segment.globalIndex);
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
        _updateState(() {
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
      _updateState(() => _activePlaybackGlobalIndex = null);
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
      if (!forceCache && segment.audioPath != null && !segment.missing) {
        continue;
      }
      if (_shouldSkipSegment(project, segment)) continue;
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
    final ordered = [...segments]
      ..sort((a, b) => a.globalIndex.compareTo(b.globalIndex));
    final providers = await ref.read(databaseProvider).getAllProviders();
    final taskFactories = [
      for (final segment in ordered)
        if (!_shouldSkipSegment(project, segment))
          () => _ensureAudioForSegment(
            project,
            segment,
            bankAssets,
            force: force,
          ),
    ];
    final failures = <Object>[];
    try {
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
        _snack(force ? 'Novel cache overwritten.' : 'Novel cache completed.');
      } else {
        _snack(
          'Novel cache completed with ${failures.length} failed segment(s).',
        );
      }
    } catch (e) {
      _snack('Generate all stopped: $e');
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

    final task = _generateAudioForSegment(
      project: project,
      segment: segment,
      asset: asset,
      provider: provider,
      force: force,
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

    if (mounted) _updateState(() => _generatingSegmentIds.add(segment.id));
    try {
      final slug = await ref
          .read(storageServiceProvider)
          .ensureNovelProjectSlug(project.id);
      final outDir = await PathService.instance.novelReaderAudioDir(slug);
      final chunks = _ttsChunksForSegment(project, activeSegment.segmentText);
      final fileBase =
          'seg_${activeSegment.globalIndex}_${_stableHash(activeCacheKey)}';
      final taskLabel =
          'Segment ${activeSegment.globalIndex + 1}: ${activeSegment.segmentText}';
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
      if (mounted) _updateState(() => _generatingSegmentIds.remove(segment.id));
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
}

extension _NovelReaderAudioHelpers on _NovelReaderEditorState {
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
}

class _WavParts {
  final Uint8List fmt;
  final Uint8List data;

  const _WavParts({required this.fmt, required this.data});
}

extension _NovelReaderEditorExport on _NovelReaderEditorState {
  Future<void> _exportBook(
    db.NovelProject project,
    List<db.NovelSegment> segments,
  ) async {
    _updateState(() => _exporting = true);
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
      if (mounted) _updateState(() => _exporting = false);
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
}
