import 'dart:io';

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

/// Phase TTS — long-form / novel TTS with project management.
/// Left panel: project list. Right panel: script editor + segments.
class PhaseTtsScreen extends ConsumerStatefulWidget {
  const PhaseTtsScreen({super.key});

  @override
  ConsumerState<PhaseTtsScreen> createState() => _PhaseTtsScreenState();
}

class _PhaseTtsScreenState extends ConsumerState<PhaseTtsScreen> {
  String? _selectedProjectId;
  final _scriptController = TextEditingController();
  bool _generatingAll = false;
  final _player = AudioPlayer();

  @override
  void dispose() {
    _scriptController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(phaseTtsProjectsStreamProvider);

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
          Text('Phase TTS',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Novel & long-form narration',
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
      AsyncValue<List<db.PhaseTtsProject>> projectsAsync) {
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
                        onTap: () {
                          setState(() => _selectedProjectId = proj.id);
                          _scriptController.text = proj.scriptText;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.auto_stories_rounded,
                                  size: 18,
                                  color: selected
                                      ? AppTheme.accentColor
                                      : Colors.white.withValues(alpha: 0.4)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                                onSelected: (v) {
                                  if (v == 'delete') {
                                    ref
                                        .read(databaseProvider)
                                        .deletePhaseTtsProject(proj.id);
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
            Icon(Icons.auto_stories_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('Select or create a project',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
          ],
        ),
      );
    }

    final projectId = _selectedProjectId!;
    final projectsAsync = ref.watch(phaseTtsProjectsStreamProvider);
    final segmentsAsync = ref.watch(phaseTtsSegmentsStreamProvider(projectId));
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get bank members for voice selection
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
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Script editor
              Expanded(flex: 3, child: _buildScriptEditor(project)),
              const VerticalDivider(width: 1),
              // Segments
              Expanded(
                  flex: 2,
                  child: _buildSegmentPanel(
                      project, segmentsAsync, bankAssets)),
            ],
          ),
        ),
        _buildActionBar(project, segmentsAsync, bankAssets),
      ],
    );
  }

  Widget _buildProjectBar(
      db.PhaseTtsProject project, List<db.VoiceAsset> bankAssets) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          Icon(Icons.auto_stories_rounded,
              color: AppTheme.accentColor, size: 18),
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
          const Spacer(),
          TextButton.icon(
            onPressed: _autoSplit,
            icon: const Icon(Icons.splitscreen_rounded, size: 16),
            label: const Text('Auto Split'),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptEditor(db.PhaseTtsProject project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('SCRIPT',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _scriptController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => _saveScript(project),
              decoration: InputDecoration(
                hintText:
                    'Paste your novel text here...\n\nEach paragraph becomes a TTS segment.',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                filled: true,
                fillColor: AppTheme.surfaceDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentPanel(
    db.PhaseTtsProject project,
    AsyncValue<List<db.PhaseTtsSegment>> segmentsAsync,
    List<db.VoiceAsset> bankAssets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('SEGMENTS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: segmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (segments) {
              if (segments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.segment_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 12),
                      Text(
                        'Click "Auto Split" to create\nsegments from script',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: segments.length,
                itemBuilder: (ctx, i) => _SegmentCard(
                  segment: segments[i],
                  index: i,
                  bankAssets: bankAssets,
                  player: _player,
                  onVoiceChanged: (voiceId) => _updateSegmentVoice(
                      segments[i], voiceId),
                  onDelete: () => ref
                      .read(databaseProvider)
                      .deletePhaseTtsSegment(segments[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    db.PhaseTtsProject project,
    AsyncValue<List<db.PhaseTtsSegment>> segmentsAsync,
    List<db.VoiceAsset> bankAssets,
  ) {
    final segments = segmentsAsync.valueOrNull ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text('${segments.length} segments',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          const Spacer(),
          FilledButton.icon(
            onPressed:
                segments.isEmpty || _generatingAll || bankAssets.isEmpty
                    ? null
                    : () => _generateAll(project, segments, bankAssets),
            icon: _generatingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate All'),
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
          title: const Text('New Phase TTS Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Project name'),
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
      await ref.read(databaseProvider).insertPhaseTtsProject(
            db.PhaseTtsProjectsCompanion(
              id: Value(id),
              name: Value(result.$1),
              bankId: Value(result.$2),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      setState(() {
        _selectedProjectId = id;
        _scriptController.clear();
      });
    }
  }

  void _saveScript(db.PhaseTtsProject project) {
    // Debounced save — update DB with current script text
    ref.read(databaseProvider).updatePhaseTtsProject(
          project.copyWith(
            scriptText: _scriptController.text,
            updatedAt: DateTime.now(),
          ),
        );
  }

  void _autoSplit() async {
    if (_selectedProjectId == null) return;
    final text = _scriptController.text.trim();
    if (text.isEmpty) return;

    final projectId = _selectedProjectId!;
    final database = ref.read(databaseProvider);

    // Clear existing segments
    await database.clearPhaseTtsSegments(projectId);

    // Split by double newlines
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (int i = 0; i < paragraphs.length; i++) {
      await database.insertPhaseTtsSegment(
        db.PhaseTtsSegmentsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(projectId),
          orderIndex: Value(i),
          segmentText: Value(paragraphs[i]),
        ),
      );
    }
  }

  void _updateSegmentVoice(db.PhaseTtsSegment segment, String? voiceId) {
    ref.read(databaseProvider).updatePhaseTtsSegment(
          segment.copyWith(voiceAssetId: Value(voiceId)),
        );
  }

  Future<void> _generateAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final assetMap = {for (final a in bankAssets) a.id: a};
    final providerMap = {for (final p in providers) p.id: p};

    setState(() => _generatingAll = true);

    final dir = await getApplicationSupportDirectory();
    final outDir = Directory(p.join(dir.path, 'phase_tts', project.id));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final database = ref.read(databaseProvider);

    for (final seg in segments) {
      if (seg.audioPath != null) continue; // skip already generated
      if (seg.voiceAssetId == null) continue; // skip unassigned

      final asset = assetMap[seg.voiceAssetId];
      if (asset == null) continue;
      final provider = providerMap[asset.providerId];
      if (provider == null) continue;

      try {
        final adapter = createAdapter(provider, modelName: asset.modelName);
        final result = await adapter.synthesize(TtsRequest(
          text: seg.segmentText,
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
            'seg_${seg.orderIndex}_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await File(filePath).writeAsBytes(result.audioBytes);

        await database.updatePhaseTtsSegment(
          seg.copyWith(audioPath: Value(filePath), error: const Value(null)),
        );
      } catch (e) {
        await database.updatePhaseTtsSegment(
          seg.copyWith(error: Value(e.toString())),
        );
      }
    }

    if (mounted) setState(() => _generatingAll = false);
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────── Segment Card ───────────────

class _SegmentCard extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> bankAssets;
  final AudioPlayer player;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onDelete;

  const _SegmentCard({
    required this.segment,
    required this.index,
    required this.bankAssets,
    required this.player,
    required this.onVoiceChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Segment number
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5))),
                ),
                const SizedBox(width: 8),
                // Voice selector
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Voice',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      isExpanded: true,
                      initialValue:
                          bankAssets.any((a) => a.id == segment.voiceAssetId)
                              ? segment.voiceAssetId
                              : null,
                      items: bankAssets
                          .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: onVoiceChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Status / play / error
                if (segment.audioPath != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        player.play(DeviceFileSource(segment.audioPath!)),
                  )
                else if (segment.error != null)
                  Tooltip(
                    message: segment.error!,
                    child: const Icon(Icons.error_rounded,
                        size: 18, color: Colors.redAccent),
                  )
                else
                  Icon(Icons.pending_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(segment.segmentText,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
