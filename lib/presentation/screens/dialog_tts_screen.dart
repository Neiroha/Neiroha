import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/dialog_tts/chat_list_view.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/editor_project_bar.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/input_bar.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/project_list_header.dart';
import 'package:neiroha/presentation/widgets/dialog_tts/settings_panel.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Dialog TTS — multi-character conversation with project management.
///
/// List mode: grid of project cards (matches Phase TTS / Video Dub).
/// Editor mode: top bar + split pane (left chat + input, right settings).
class DialogTtsScreen extends ConsumerStatefulWidget {
  const DialogTtsScreen({super.key});

  @override
  ConsumerState<DialogTtsScreen> createState() => _DialogTtsScreenState();
}

class _DialogTtsScreenState extends ConsumerState<DialogTtsScreen> {
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) {
      return _buildProjectListScreen();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _selectedProjectId = null);
      },
      child: _DialogTtsEditor(
        key: ValueKey(_selectedProjectId),
        projectId: _selectedProjectId!,
        onClose: () => setState(() => _selectedProjectId = null),
      ),
    );
  }

  // ───────────────── List mode ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(dialogTtsProjectsStreamProvider);
    return Column(
      children: [
        ProjectListHeader(onCreate: _createProject),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (projects) => ProjectCardGrid(
              emptyLabel: AppLocalizations.of(context).uiNoDialogProjectsYet,
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.forum_rounded,
                  ),
              ],
              onOpen: (id) => setState(() => _selectedProjectId = id),
              onDelete: (id) {
                ref.read(databaseProvider).deleteDialogTtsProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiCreateAVoiceBankFirst),
          ),
        );
      }
      return;
    }

    final result = await showCreateDialogTtsProjectDialog(
      context: context,
      banks: banks,
    );
    if (result == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    await ref
        .read(databaseProvider)
        .insertDialogTtsProject(
          db.DialogTtsProjectsCompanion(
            id: Value(id),
            name: Value(result.name),
            bankId: Value(result.bankId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (mounted) setState(() => _selectedProjectId = id);
  }
}

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
    final project = projectsAsync.valueOrNull
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
    final bankMembers = membersAsync.valueOrNull ?? [];
    final allAssets = assetsAsync.valueOrNull ?? [];
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
            left: LayoutBuilder(
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
                          linesAsync.valueOrNull ?? const [],
                          startIndex,
                          assetMap,
                        ),
                        onGenerate: bankAssets.isEmpty
                            ? null
                            : (line) => _generateOne(project, line, bankAssets),
                        onDelete: (id) =>
                            ref.read(databaseProvider).deleteDialogTtsLine(id),
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
                      onVoiceChanged: (v) => setState(() => _inputVoiceId = v),
                      onSend: (text) => _addLine(project, bankAssets, text),
                      maxHeight: inputMaxHeight,
                    ),
                  ],
                );
              },
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
                linesAsync.valueOrNull ?? const [],
                bankAssets,
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
    final assets = ref.read(voiceAssetsStreamProvider).valueOrNull ?? const [];
    final voiceName =
        assets.where((a) => a.id == line.voiceAssetId).firstOrNull?.name ??
        'Line';
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
            request: TtsRequest(
              text: line.lineText,
              voice: asset.presetVoiceName ?? asset.name,
              speed: asset.speed,
              textLang: provider.adapterType == 'gptSovits'
                  ? asset.modelName
                  : null,
              presetVoiceName: asset.presetVoiceName,
              voiceInstruction: asset.voiceInstruction,
              refAudioPath: asset.refAudioPath,
              promptText: asset.promptText,
              promptLang: asset.promptLang,
            ),
          );
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'line_${line.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
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
