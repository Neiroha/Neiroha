import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/story_track_editor.dart'
    show StoryTrackEditor, TimelineDragButton, TimelineDropPayload;
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

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
  final Set<String> _generatingSegmentIds = <String>{};
  final Set<String> _seededProjects = <String>{};

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedProjectId == null) {
      return _buildProjectListScreen();
    }
    return _buildProjectContent();
  }

  // ───────────────── List mode (card grid) ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(phaseTtsProjectsStreamProvider);
    return Column(
      children: [
        _buildListHeader(context),
        const Divider(height: 1),
        Expanded(
          child: projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) => ProjectCardGrid(
              projects: [
                for (final p in projects)
                  ProjectCardData(
                    id: p.id,
                    name: p.name,
                    updatedAt: p.updatedAt,
                    icon: Icons.auto_stories_rounded,
                    subtitle: _scriptPreview(p.scriptText),
                  ),
              ],
              onOpen: (id) {
                final proj = projects.firstWhere((p) => p.id == id);
                setState(() => _selectedProjectId = id);
                _scriptController.text = proj.scriptText;
              },
              onDelete: (id) {
                ref.read(databaseProvider).deletePhaseTtsProject(id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(BuildContext context) {
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

  String? _scriptPreview(String scriptText) {
    final trimmed = scriptText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
  }

  // ───────────────── Editor mode ─────────────────

  Widget _buildProjectContent() {
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

    final clipsAsync =
        ref.watch(timelineClipsStreamProvider('phase:$projectId'));
    final segments = segmentsAsync.valueOrNull;
    final clips = clipsAsync.valueOrNull;
    if (segments != null &&
        clips != null &&
        clips.isEmpty &&
        !_seededProjects.contains(projectId) &&
        segments.any((s) => s.audioPath != null)) {
      _seededProjects.add(projectId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seedTimeline(projectId, segments, assetMap);
      });
    }

    return Column(
      children: [
        _buildProjectBar(project, bankAssets),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.6,
            left: _buildScriptEditor(project),
            rightBuilder: (_) =>
                _buildSegmentPanel(project, segmentsAsync, bankAssets),
          ),
        ),
        StoryTrackEditor(
          projectId: project.id,
          projectType: 'phase',
          projectName: project.name,
        ),
        // Inline audio player — replaces the global bottom bar so the
        // current clip surfaces above the action/input row.
        const PersistentAudioBar(),
        _buildActionBar(project, segmentsAsync, bankAssets),
      ],
    );
  }

  Widget _buildProjectBar(
      db.PhaseTtsProject project, List<db.VoiceAsset> bankAssets) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to projects',
            onPressed: () => _closeEditor(project),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Icon(Icons.auto_stories_rounded,
              color: AppTheme.accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
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
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _autoSplit,
            icon: const Icon(Icons.splitscreen_rounded, size: 16),
            label: const Text('Auto Split'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _closeEditor(project),
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Persist the current script (edits autosave on change, but flushing here
  /// covers the case where the user clicks Save before the debounce lands)
  /// and return to the project grid.
  void _closeEditor(db.PhaseTtsProject project) {
    ref.read(databaseProvider).updatePhaseTtsProject(
          project.copyWith(
            scriptText: _scriptController.text,
            updatedAt: DateTime.now(),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          duration: Duration(seconds: 1),
        ),
      );
      setState(() => _selectedProjectId = null);
    }
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
                itemBuilder: (ctx, i) {
                  final seg = segments[i];
                  return _SegmentCard(
                    segment: seg,
                    index: i,
                    bankAssets: bankAssets,
                    isGenerating: _generatingSegmentIds.contains(seg.id),
                    onPlay: () {
                      if (seg.audioPath == null) return;
                      final voiceName = bankAssets
                              .where((a) => a.id == seg.voiceAssetId)
                              .firstOrNull
                              ?.name ??
                          'Segment ${i + 1}';
                      ref.read(playbackNotifierProvider.notifier).load(
                            seg.audioPath!,
                            seg.segmentText,
                            subtitle: voiceName,
                          );
                    },
                    onGenerate: seg.voiceAssetId == null ||
                            _generatingSegmentIds.contains(seg.id)
                        ? null
                        : () => _generateOne(project, seg, bankAssets),
                    onAddToTimeline: seg.audioPath == null
                        ? null
                        : () => _addSegmentToTimeline(
                              project,
                              seg,
                              bankAssets,
                              i,
                            ),
                    onVoiceChanged: (voiceId) =>
                        _updateSegmentVoice(seg, voiceId),
                    onDelete: () => ref
                        .read(databaseProvider)
                        .deletePhaseTtsSegment(seg.id),
                  );
                },
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
    setState(() => _generatingAll = true);
    for (final seg in segments) {
      if (seg.audioPath != null) continue;
      if (seg.voiceAssetId == null) continue;
      await _generateOne(project, seg, bankAssets);
    }
    if (mounted) setState(() => _generatingAll = false);
  }

  Future<void> _generateOne(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (seg.voiceAssetId == null) return;
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final assetMap = {for (final a in bankAssets) a.id: a};
    final providerMap = {for (final p in providers) p.id: p};
    final asset = assetMap[seg.voiceAssetId];
    if (asset == null) return;
    final provider = providerMap[asset.providerId];
    if (provider == null) return;

    final slug =
        await ref.read(storageServiceProvider).ensurePhaseProjectSlug(project.id);
    final outDir = await PathService.instance.phaseTtsDir(slug);
    final database = ref.read(databaseProvider);

    setState(() => _generatingSegmentIds.add(seg.id));
    try {
      final adapter = createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(TtsRequest(
        text: seg.segmentText,
        voice: asset.presetVoiceName ?? asset.name,
        speed: asset.speed,
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
        presetVoiceName: asset.presetVoiceName,
        voiceInstruction: asset.voiceInstruction,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
      ));
      final ext = result.contentType.contains('wav') ? '.wav' : '.mp3';
      final filePath = PathService.dedupeFilename(
        outDir,
        'seg_${seg.orderIndex}_${PathService.formatTimestamp()}',
        ext,
      );
      await File(filePath).writeAsBytes(result.audioBytes);
      final durationSec = await measureAudioDuration(filePath);
      await database.updatePhaseTtsSegment(
        seg.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
      await _syncTimelineClip(
        projectId: project.id,
        sourceLineId: seg.id,
        audioPath: filePath,
        durationSec: durationSec,
        label: asset.name,
      );
    } catch (e) {
      await database.updatePhaseTtsSegment(
        seg.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _generatingSegmentIds.remove(seg.id));
    }
  }

  Future<void> _addSegmentToTimeline(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets,
    int index,
  ) async {
    if (seg.audioPath == null) return;
    final voiceName = bankAssets
            .where((a) => a.id == seg.voiceAssetId)
            .firstOrNull
            ?.name ??
        'Segment ${index + 1}';
    double? duration = seg.audioDuration;
    if (duration == null || duration <= 0) {
      duration = await measureAudioDuration(seg.audioPath!);
      if (duration != null) {
        await ref.read(databaseProvider).updatePhaseTtsSegment(
              seg.copyWith(audioDuration: Value(duration)),
            );
      }
    }
    await _syncTimelineClip(
      projectId: project.id,
      sourceLineId: seg.id,
      audioPath: seg.audioPath!,
      durationSec: duration,
      label: voiceName,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${seg.segmentText.characters.take(30)}…" to timeline'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Upsert a lane-0 timeline clip for a segment after generation.
  /// Replaces any existing clip tied to the same [sourceLineId] so regenerations
  /// don't pile up. New clips are appended after the last lane-0 generated clip.
  Future<void> _syncTimelineClip({
    required String projectId,
    required String sourceLineId,
    required String audioPath,
    required double? durationSec,
    required String label,
  }) async {
    final database = ref.read(databaseProvider);
    await database.deleteTimelineClipsByLine(sourceLineId);
    final existing = await database.getTimelineClips(projectId, 'phase');
    int cursorMs = 0;
    for (final c in existing) {
      if (c.laneIndex != 0) continue;
      if (c.sourceType != 'generated') continue;
      final end = c.startTimeMs + ((c.durationSec ?? 0) * 1000).round();
      if (end > cursorMs) cursorMs = end;
    }
    await database.insertTimelineClip(
      db.TimelineClipsCompanion(
        id: Value(const Uuid().v4()),
        projectId: Value(projectId),
        projectType: const Value('phase'),
        laneIndex: const Value(0),
        startTimeMs: Value(cursorMs),
        durationSec: Value(durationSec),
        audioPath: Value(audioPath),
        sourceType: const Value('generated'),
        sourceLineId: Value(sourceLineId),
        label: Value(label),
      ),
    );
  }

  Future<void> _seedTimeline(
    String projectId,
    List<db.PhaseTtsSegment> segments,
    Map<String, db.VoiceAsset> assetMap,
  ) async {
    final database = ref.read(databaseProvider);
    int cursorMs = 0;
    for (final seg in segments) {
      if (seg.audioPath == null) continue;
      final dur = seg.audioDuration ?? 0;
      final voiceName = seg.voiceAssetId != null
          ? (assetMap[seg.voiceAssetId]?.name ?? 'Voice')
          : 'Voice';
      await database.insertTimelineClip(
        db.TimelineClipsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(projectId),
          projectType: const Value('phase'),
          laneIndex: const Value(0),
          startTimeMs: Value(cursorMs),
          durationSec: Value(dur > 0 ? dur : null),
          audioPath: Value(seg.audioPath!),
          sourceType: const Value('generated'),
          sourceLineId: Value(seg.id),
          label: Value(voiceName),
        ),
      );
      cursorMs += (dur * 1000).round();
    }
  }
}

// ─────────────── Segment Card ───────────────

class _SegmentCard extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> bankAssets;
  final bool isGenerating;
  final VoidCallback onPlay;
  final VoidCallback? onGenerate;
  final VoidCallback? onAddToTimeline;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onDelete;

  const _SegmentCard({
    required this.segment,
    required this.index,
    required this.bankAssets,
    required this.isGenerating,
    required this.onPlay,
    required this.onGenerate,
    required this.onAddToTimeline,
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
                if (isGenerating)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (segment.audioPath != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onPlay,
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
                  icon: Icon(
                    segment.audioPath != null
                        ? Icons.refresh_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                    color: onGenerate == null
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppTheme.accentColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: segment.audioPath != null
                      ? 'Regenerate'
                      : 'Generate',
                  onPressed: onGenerate,
                ),
                const SizedBox(width: 4),
                TimelineDragButton(
                  enabled: onAddToTimeline != null,
                  payload: segment.audioPath == null
                      ? null
                      : TimelineDropPayload(
                          audioPath: segment.audioPath!,
                          label: bankAssets
                                  .where((a) => a.id == segment.voiceAssetId)
                                  .firstOrNull
                                  ?.name ??
                              'Segment ${index + 1}',
                          durationSec: segment.audioDuration,
                          sourceLineId: segment.id,
                        ),
                  onTap: onAddToTimeline,
                ),
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
