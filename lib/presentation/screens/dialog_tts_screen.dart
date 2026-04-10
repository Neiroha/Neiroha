import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:q_vox_lab/data/adapters/tts_adapter.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/presentation/widgets/resizable_split_pane.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// Dialog TTS — multi-character conversation with project management.
/// Left panel: project list. Right panel: Telegram-like chat view.
class DialogTtsScreen extends ConsumerStatefulWidget {
  const DialogTtsScreen({super.key});

  @override
  ConsumerState<DialogTtsScreen> createState() => _DialogTtsScreenState();
}

class _DialogTtsScreenState extends ConsumerState<DialogTtsScreen> {
  String? _selectedProjectId;
  bool _generatingAll = false;
  final _player = AudioPlayer();
  String? _playingLineId;
  Duration _currentPosition = Duration.zero;
  final _textController = TextEditingController();
  String? _inputVoiceId;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playingLineId = null; _currentPosition = Duration.zero; });
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(dialogTtsProjectsStreamProvider);

    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.3,
            left: _buildProjectList(projectsAsync),
            rightBuilder: (_) => _buildProjectContent(),
          ),
        ),
      ],
    );
  }

  // ───────────────── Header ─────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Dialog TTS',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Multi-character conversations',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  // ───────────────── Project List (left) ─────────────────

  Widget _buildProjectList(
      AsyncValue<List<db.DialogTtsProject>> projectsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('PROJECTS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) {
              if (projects.isEmpty) {
                return Center(
                  child: Text('No projects yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: projects.length,
                itemBuilder: (ctx, i) {
                  final proj = projects[i];
                  final selected = _selectedProjectId == proj.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: selected
                          ? AppTheme.accentColor.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setState(() => _selectedProjectId = proj.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.forum_rounded,
                                  size: 18,
                                  color: selected
                                      ? AppTheme.accentColor
                                      : Colors.white
                                          .withValues(alpha: 0.4)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(proj.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      _formatDate(proj.updatedAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withValues(alpha: 0.3)),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                icon: Icon(Icons.more_vert_rounded,
                                    size: 16,
                                    color: Colors.white
                                        .withValues(alpha: 0.3)),
                                onSelected: (v) {
                                  if (v == 'delete') {
                                    ref
                                        .read(databaseProvider)
                                        .deleteDialogTtsProject(proj.id);
                                    if (_selectedProjectId == proj.id) {
                                      setState(
                                          () => _selectedProjectId = null);
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(
                                            color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────── Project Content (right) ─────────────────

  Widget _buildProjectContent() {
    if (_selectedProjectId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Select or create a project',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 15)),
          ],
        ),
      );
    }

    final projectId = _selectedProjectId!;
    final projectsAsync = ref.watch(dialogTtsProjectsStreamProvider);
    final linesAsync = ref.watch(dialogTtsLinesStreamProvider(projectId));
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get bank members
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
        // Project info bar
        _buildProjectBar(project, bankAssets),
        const Divider(height: 1),
        // Chat messages
        Expanded(child: _buildChatView(linesAsync, assetMap)),
        // Action bar
        _buildChatActionBar(project, linesAsync, bankAssets),
        // Input bar
        _buildInputBar(project, bankAssets),
      ],
    );
  }

  Widget _buildProjectBar(
      db.DialogTtsProject project, List<db.VoiceAsset> bankAssets) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          Icon(Icons.forum_rounded, color: AppTheme.accentColor, size: 18),
          const SizedBox(width: 10),
          Text(project.name,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${bankAssets.length} voices',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(
    AsyncValue<List<db.DialogTtsLine>> linesAsync,
    Map<String, db.VoiceAsset> assetMap,
  ) {
    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (lines) {
        if (lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                Text('Add dialog lines below',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13)),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxBubbleWidth = constraints.maxWidth * 0.6;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: lines.length,
              itemBuilder: (ctx, i) {
                final line = lines[i];
                final asset = line.voiceAssetId != null
                    ? assetMap[line.voiceAssetId]
                    : null;
                return _ChatBubble(
                  line: line,
                  asset: asset,
                  isPlaying: _playingLineId == line.id,
                  playbackPosition: _playingLineId == line.id ? _currentPosition : null,
                  maxBubbleWidth: maxBubbleWidth,
                  onPlay: () => _playLine(line),
                  onDelete: () => ref
                      .read(databaseProvider)
                      .deleteDialogTtsLine(line.id),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatActionBar(
    db.DialogTtsProject project,
    AsyncValue<List<db.DialogTtsLine>> linesAsync,
    List<db.VoiceAsset> bankAssets,
  ) {
    final lines = linesAsync.valueOrNull ?? [];
    final ungenerated =
        lines.where((l) => l.audioPath == null && l.voiceAssetId != null).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text('${lines.length} lines',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          if (ungenerated > 0) ...[
            const SizedBox(width: 8),
            Text('($ungenerated pending)',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12)),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed:
                lines.isEmpty || _generatingAll || bankAssets.isEmpty
                    ? null
                    : () => _generateAll(project, lines, bankAssets),
            icon: _generatingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Generate All'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(
      db.DialogTtsProject project, List<db.VoiceAsset> bankAssets) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Character picker
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: 'Voice',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              isExpanded: true,
              initialValue:
                  bankAssets.any((a) => a.id == _inputVoiceId)
                      ? _inputVoiceId
                      : null,
              items: bankAssets
                  .map((a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _inputVoiceId = v),
            ),
          ),
          const SizedBox(width: 8),
          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type dialog line...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                isDense: true,
                filled: true,
                fillColor: AppTheme.surfaceDim,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          IconButton.filled(
            onPressed: _inputVoiceId == null
                ? null
                : () => _addLine(project),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
              disabledBackgroundColor:
                  AppTheme.accentColor.withValues(alpha: 0.3),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  // ───────────────── Actions ─────────────────

  void _createProject() async {
    final banksAsync = ref.read(voiceBanksStreamProvider);
    final banks = banksAsync.valueOrNull ?? [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create a Voice Bank first')));
      }
      return;
    }

    final nameCtrl = TextEditingController();
    String selectedBankId = banks.first.id;

    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Dialog TTS Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Voice Bank'),
                isExpanded: true,
                initialValue: selectedBankId,
                items: banks
                    .map((b) => DropdownMenuItem(
                        value: b.id, child: Text(b.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedBankId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (nameCtrl.text, selectedBankId)),
                child: const Text('Create')),
          ],
        ),
      ),
    );

    if (result != null && result.$1.isNotEmpty) {
      final id = const Uuid().v4();
      final now = DateTime.now();
      await ref.read(databaseProvider).insertDialogTtsProject(
            db.DialogTtsProjectsCompanion(
              id: Value(id),
              name: Value(result.$1),
              bankId: Value(result.$2),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      setState(() => _selectedProjectId = id);
    }
  }

  Future<void> _addLine(db.DialogTtsProject project) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _inputVoiceId == null) return;

    final database = ref.read(databaseProvider);
    final lines = await database.getDialogTtsLines(project.id);
    final nextIndex = lines.isEmpty ? 0 : lines.last.orderIndex + 1;

    await database.insertDialogTtsLine(
      db.DialogTtsLinesCompanion(
        id: Value(const Uuid().v4()),
        projectId: Value(project.id),
        orderIndex: Value(nextIndex),
        lineText: Value(text),
        voiceAssetId: Value(_inputVoiceId),
      ),
    );

    await database.updateDialogTtsProject(
      project.copyWith(updatedAt: DateTime.now()),
    );

    _textController.clear();
  }

  Future<void> _playLine(db.DialogTtsLine line) async {
    if (line.audioPath == null) return;
    if (_playingLineId == line.id) {
      await _player.stop();
      setState(() => _playingLineId = null);
    } else {
      await _player.play(DeviceFileSource(line.audioPath!));
      setState(() => _playingLineId = line.id);
    }
  }

  Future<void> _generateAll(
    db.DialogTtsProject project,
    List<db.DialogTtsLine> lines,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final assetMap = {for (final a in bankAssets) a.id: a};
    final providerMap = {for (final p in providers) p.id: p};

    setState(() => _generatingAll = true);

    final dir = await getApplicationSupportDirectory();
    final outDir = Directory(p.join(dir.path, 'dialog_tts', project.id));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final database = ref.read(databaseProvider);

    for (final line in lines) {
      if (line.audioPath != null) continue;
      if (line.voiceAssetId == null) continue;

      final asset = assetMap[line.voiceAssetId];
      if (asset == null) continue;
      final provider = providerMap[asset.providerId];
      if (provider == null) continue;

      try {
        final adapter = createAdapter(provider, modelName: asset.modelName);
        final result = await adapter.synthesize(TtsRequest(
          text: line.lineText,
          voice: asset.presetVoiceName ?? asset.name,
          speed: asset.speed,
          presetVoiceName: asset.presetVoiceName,
          voiceInstruction: asset.voiceInstruction,
          refAudioPath: asset.refAudioPath,
          promptText: asset.promptText,
          promptLang: asset.promptLang,
        ));
        final ext = result.contentType.contains('wav') ? 'wav' : 'mp3';
        final filePath = p.join(outDir.path,
            'line_${line.orderIndex}_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await File(filePath).writeAsBytes(result.audioBytes);

        // Detect audio duration
        final durationPlayer = AudioPlayer();
        double? duration;
        try {
          await durationPlayer.setSource(DeviceFileSource(filePath));
          final d = await durationPlayer.getDuration();
          if (d != null) {
            duration = d.inMilliseconds / 1000.0;
          }
        } catch (_) {
          // Duration detection failed, leave as null
        } finally {
          durationPlayer.dispose();
        }

        await database.updateDialogTtsLine(
          line.copyWith(
            audioPath: Value(filePath),
            audioDuration: Value(duration),
            error: const Value(null),
          ),
        );
      } catch (e) {
        await database.updateDialogTtsLine(
          line.copyWith(error: Value(e.toString())),
        );
      }
    }

    if (mounted) setState(() => _generatingAll = false);
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────── Chat Bubble (Telegram-like) ───────────────

class _ChatBubble extends StatelessWidget {
  final db.DialogTtsLine line;
  final db.VoiceAsset? asset;
  final bool isPlaying;
  final Duration? playbackPosition;
  final double maxBubbleWidth;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _ChatBubble({
    required this.line,
    required this.asset,
    required this.isPlaying,
    this.playbackPosition,
    required this.maxBubbleWidth,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = asset?.name ?? 'Unknown';
    final hasAudio = line.audioPath != null;
    final hasError = line.error != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(name),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBright,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.lineText,
                            style: const TextStyle(fontSize: 14)),
                        if (hasAudio || hasError) ...[
                          const SizedBox(height: 8),
                          _buildAudioRow(hasAudio, hasError),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.2)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    if (asset?.avatarPath != null &&
        File(asset!.avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(File(asset!.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildAudioRow(bool hasAudio, bool hasError) {
    if (hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_rounded, size: 16, color: Colors.redAccent),
          const SizedBox(width: 6),
          Text('Error',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.redAccent.withValues(alpha: 0.7))),
        ],
      );
    }

    // Playback progress fraction (0.0 – 1.0)
    final double progressFraction;
    if (isPlaying && playbackPosition != null && line.audioDuration != null && line.audioDuration! > 0) {
      progressFraction = (playbackPosition!.inMilliseconds / (line.audioDuration! * 1000)).clamp(0.0, 1.0);
    } else {
      progressFraction = 0.0;
    }

    // Time label: "played/total" during playback, "mm:ss" otherwise
    String timeText;
    if (isPlaying && playbackPosition != null && line.audioDuration != null) {
      final playedSecs = playbackPosition!.inSeconds;
      final totalSecs = line.audioDuration!.floor();
      timeText = '$playedSecs/$totalSecs';
    } else if (line.audioDuration != null) {
      final totalSecs = line.audioDuration!;
      final mins = (totalSecs / 60).floor();
      final secs = (totalSecs % 60).floor();
      timeText = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      timeText = '--:--';
    }

    const int barCount = 30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform — max 50% of bubble width
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth * 0.5),
            child: SizedBox(
              height: 26,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(barCount, (i) {
                  final p = i / barCount;
                  final wave1 = math.sin(p * math.pi * 4).abs();
                  final wave2 = math.sin(p * math.pi * 7 + 1.2).abs();
                  final wave3 = math.sin(p * math.pi * 2.5 + 0.5).abs();
                  final h = 3.0 + (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25) * 20.0;
                  final isPlayedBar = i / barCount < progressFraction;
                  return Expanded(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        height: h,
                        decoration: BoxDecoration(
                          color: isPlayedBar
                              ? AppTheme.accentColor
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeText,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: isPlaying
                ? AppTheme.accentColor
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
