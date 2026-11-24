part of '../../screens/dialog_tts_screen.dart';

// ───────────────── Editor mode ─────────────────

class _DialogTtsEditor extends ConsumerStatefulWidget {
  final String projectId;
  final VoidCallback onClose;

  const _DialogTtsEditor({
    super.key,
    required this.projectId,
    required this.onClose,
  });

  @override
  ConsumerState<_DialogTtsEditor> createState() => _DialogTtsEditorState();
}

class _DialogTtsEditorState extends ConsumerState<_DialogTtsEditor> {
  String? _inputVoiceId;
  bool _generatingAll = false;
  bool _autoGenerateOnSend = false;
  bool _autoPlayAfterGenerate = false;
  final Set<String> _generatingLineIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(dialogTtsProjectsStreamProvider);
    final project = projectsAsync.value
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) {
      return Center(child: CircularProgressIndicator());
    }

    final linesAsync = ref.watch(
      dialogTtsLinesStreamProvider(widget.projectId),
    );
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final membersAsync = ref.watch(bankMembersStreamProvider(project.bankId));
    final bankMembers = membersAsync.value ?? [];
    final allAssets = assetsAsync.value ?? [];
    final assetMap = {for (final a in allAssets) a.id: a};
    final bankAssets = bankMembers
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();

    return Column(
      children: [
        EditorProjectBar(
          project: project,
          voiceCount: bankAssets.length,
          onClose: widget.onClose,
        ),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.68,
            compactRightIcon: Icons.tune_rounded,
            compactRightLabel: AppLocalizations.of(context).navSettings,
            left: DialogModeView(
              bankAssets: bankAssets,
              voiceId: _inputVoiceId,
              script: LayoutBuilder(
                builder: (ctx, leftConstraints) {
                  final inputMaxHeight = leftConstraints.maxHeight * 0.3;
                  return Column(
                    children: [
                      Expanded(
                        child: ChatListView(
                          linesAsync: linesAsync,
                          assetMap: assetMap,
                          generatingLineIds: _generatingLineIds,
                          onPlay: _playLine,
                          onPlayFrom: (startIndex) => _playFrom(
                            linesAsync.value ?? const [],
                            startIndex,
                            assetMap,
                          ),
                          onGenerate: bankAssets.isEmpty
                              ? null
                              : (line) =>
                                    _generateOne(project, line, bankAssets),
                          onDelete: (id) => ref
                              .read(databaseProvider)
                              .deleteDialogTtsLine(id),
                          onReorder: (oldIndex, newIndex) => ref
                              .read(databaseProvider)
                              .reorderDialogLine(
                                widget.projectId,
                                oldIndex,
                                newIndex,
                              ),
                        ),
                      ),
                      const PersistentAudioBar(),
                      InputBar(
                        bankAssets: bankAssets,
                        voiceId: _inputVoiceId,
                        onVoiceChanged: (v) =>
                            setState(() => _inputVoiceId = v),
                        onSend: (text) => _addLine(project, bankAssets, text),
                        maxHeight: inputMaxHeight,
                      ),
                    ],
                  );
                },
              ),
            ),
            rightBuilder: (_) => SettingsPanel(
              linesAsync: linesAsync,
              bankAssets: bankAssets,
              activeVoiceId: _inputVoiceId,
              generatingAll: _generatingAll,
              autoGenerateOnSend: _autoGenerateOnSend,
              autoPlayAfterGenerate: _autoPlayAfterGenerate,
              onPickVoice: (id) => setState(() => _inputVoiceId = id),
              onToggleAutoGenerate: (v) =>
                  setState(() => _autoGenerateOnSend = v),
              onToggleAutoPlay: (v) =>
                  setState(() => _autoPlayAfterGenerate = v),
              onGenerateAll: () => _generateAll(
                project,
                linesAsync.value ?? const [],
                bankAssets,
              ),
              onNormalize: _generatingLineIds.isNotEmpty
                  ? null
                  : () => unawaited(
                      runLoudnessNormalization(
                        context: context,
                        ref: ref,
                        bankId: project.bankId,
                        items: [
                          for (final l
                              in linesAsync.value ?? const <db.DialogTtsLine>[])
                            if (l.audioPath != null && !l.missing)
                              LoudnessItem(
                                id: l.id,
                                path: l.audioPath!,
                                voiceAssetId: l.voiceAssetId,
                              ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────── Actions ─────────────────

  Future<void> _addLine(
    db.DialogTtsProject project,
    List<db.VoiceAsset> bankAssets,
    String text,
  ) async {
    final voiceId = _inputVoiceId;
    if (text.isEmpty || voiceId == null) return;

    final database = ref.read(databaseProvider);
    final lines = await database.getDialogTtsLines(project.id);
    final nextIndex = lines.isEmpty ? 0 : lines.last.orderIndex + 1;
    final newId = const Uuid().v4();

    await database.insertDialogTtsLine(
      db.DialogTtsLinesCompanion(
        id: Value(newId),
        projectId: Value(project.id),
        orderIndex: Value(nextIndex),
        lineText: Value(text),
        voiceAssetId: Value(voiceId),
      ),
    );

    await database.updateDialogTtsProject(
      project.copyWith(updatedAt: DateTime.now()),
    );

    if (_autoGenerateOnSend && bankAssets.isNotEmpty) {
      unawaited(_generateInsertedLine(project, bankAssets, newId));
    }
  }

  Future<void> _generateInsertedLine(
    db.DialogTtsProject project,
    List<db.VoiceAsset> bankAssets,
    String lineId,
  ) async {
    try {
      final database = ref.read(databaseProvider);
      final inserted = (await database.getDialogTtsLines(
        project.id,
      )).firstWhere((l) => l.id == lineId);
      await _generateOne(project, inserted, bankAssets);

      if (!mounted || !_autoPlayAfterGenerate) return;
      final updated = (await database.getDialogTtsLines(
        project.id,
      )).firstWhere((l) => l.id == lineId);
      if (updated.audioPath != null) {
        await _playLine(updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiAutoGenerateFailed(e)),
        ),
      );
    }
  }

  Future<void> _playFrom(
    List<db.DialogTtsLine> lines,
    int startIndex,
    Map<String, db.VoiceAsset> assetMap,
  ) async {
    final items = <({String audioPath, String title, String? subtitle})>[];
    for (int i = startIndex; i < lines.length; i++) {
      final l = lines[i];
      if (l.audioPath == null) continue;
      final voiceName = l.voiceAssetId != null
          ? assetMap[l.voiceAssetId]?.name
          : null;
      items.add((
        audioPath: l.audioPath!,
        title: l.lineText,
        subtitle: voiceName,
      ));
    }
    if (items.isEmpty) return;
    unawaited(
      ref.read(playbackNotifierProvider.notifier).playSequenceFrom(items),
    );
  }

  Future<void> _playLine(db.DialogTtsLine line) async {
    if (line.audioPath == null) return;
    final playback = ref.read(playbackNotifierProvider);
    final notifier = ref.read(playbackNotifierProvider.notifier);
    if (playback.audioPath == line.audioPath && playback.isPlaying) {
      await notifier.stop();
      return;
    }
    final assets = ref.read(voiceAssetsStreamProvider).value ?? const [];
    final voiceName =
        assets.where((a) => a.id == line.voiceAssetId).firstOrNull?.name ??
        AppLocalizations.of(context).dialogLineFallback;
    await notifier.load(line.audioPath!, line.lineText, subtitle: voiceName);
    if (line.audioDuration == null) {
      ref
          .read(audioPlayerProvider)
          .onDurationChanged
          .first
          .then((d) async {
            final secs = d.inMilliseconds / 1000.0;
            await ref
                .read(databaseProvider)
                .updateDialogTtsLine(line.copyWith(audioDuration: Value(secs)));
          })
          .catchError((_) {});
    }
  }

  Future<void> _generateAll(
    db.DialogTtsProject project,
    List<db.DialogTtsLine> lines,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (lines.isEmpty || bankAssets.isEmpty || _generatingAll) return;
    setState(() => _generatingAll = true);
    try {
      await Future.wait([
        for (final line in lines)
          if (line.audioPath == null && line.voiceAssetId != null)
            _generateOne(project, line, bankAssets),
      ]);
    } finally {
      if (mounted) setState(() => _generatingAll = false);
    }
  }

  Future<void> _generateOne(
    db.DialogTtsProject project,
    db.DialogTtsLine line,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (line.voiceAssetId == null) return;
    final database = ref.read(databaseProvider);

    setState(() => _generatingLineIds.add(line.id));
    try {
      final providers = await database.getAllProviders();
      final assetMap = {for (final a in bankAssets) a.id: a};
      final providerMap = {for (final p in providers) p.id: p};
      final asset = assetMap[line.voiceAssetId];
      if (asset == null) return;
      final provider = providerMap[asset.providerId];
      if (provider == null) return;
      if (mounted) {
        warnIfVoiceHealthFailedOnce(context: context, ref: ref, asset: asset);
      }

      final slug = await ref
          .read(storageServiceProvider)
          .ensureDialogProjectSlug(project.id);
      final outDir = await PathService.instance.dialogTtsDir(slug);

      final result = await ref
          .read(ttsQueueServiceProvider)
          .synthesize(
            provider: provider,
            modelName: asset.modelName,
            source: 'Dialog TTS',
            label: 'Line ${line.orderIndex + 1}: ${line.lineText}',
            request: quickTtsRequest(asset, provider, line.lineText),
          );
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'line_${line.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      await ref
          .read(autoLoudnessServiceProvider)
          .normalizeGenerated(
            enabled: project.autoNormalizeLoudness,
            path: filePath,
            bankId: project.bankId,
            voiceAssetId: asset.id,
          );
      final durationSec = await measureAudioDuration(filePath);
      await database.updateDialogTtsLine(
        line.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
    } catch (e) {
      await database.updateDialogTtsLine(
        line.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _generatingLineIds.remove(line.id));
    }
  }
}
