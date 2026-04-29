import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/phase_tts/action_bar.dart';
import 'package:neiroha/presentation/widgets/phase_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/phase_tts/editor_project_bar.dart';
import 'package:neiroha/presentation/widgets/phase_tts/project_list_header.dart';
import 'package:neiroha/presentation/widgets/phase_tts/script_editor.dart';
import 'package:neiroha/presentation/widgets/phase_tts/segment_panel.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
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
        ProjectListHeader(onCreate: _createProject),
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
          onClose: () => _closeEditor(project),
          onAutoSplit: _autoSplit,
          onSave: () => _closeEditor(project),
        ),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.6,
            left: ScriptEditor(
              controller: _scriptController,
              onChanged: () => _saveScript(project),
            ),
            rightBuilder: (_) => SegmentPanel(
              segmentsAsync: segmentsAsync,
              bankAssets: bankAssets,
              generatingSegmentIds: _generatingSegmentIds,
              onPlay: (seg, i) => _playSegment(seg, i, bankAssets),
              onGenerate: bankAssets.isEmpty
                  ? null
                  : (seg) => _generateOne(project, seg, bankAssets),
              onVoiceChanged: (seg, voiceId) =>
                  _updateSegmentVoice(seg, voiceId),
              onDelete: (id) =>
                  ref.read(databaseProvider).deletePhaseTtsSegment(id),
            ),
          ),
        ),
        const PersistentAudioBar(),
        PhaseTtsActionBar(
          segmentCount: segmentsAsync.valueOrNull?.length ?? 0,
          hasBankAssets: bankAssets.isNotEmpty,
          generatingAll: _generatingAll,
          onGenerateAll: () => _generateAll(
              project, segmentsAsync.valueOrNull ?? const [], bankAssets),
        ),
      ],
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

  // ───────────────── Actions ─────────────────

  void _playSegment(
      db.PhaseTtsSegment seg, int index, List<db.VoiceAsset> bankAssets) {
    if (seg.audioPath == null) return;
    final voiceName = bankAssets
            .where((a) => a.id == seg.voiceAssetId)
            .firstOrNull
            ?.name ??
        'Segment ${index + 1}';
    ref.read(playbackNotifierProvider.notifier).load(
          seg.audioPath!,
          seg.segmentText,
          subtitle: voiceName,
        );
  }

  void _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create a Voice Bank first')));
      }
      return;
    }

    final result = await showCreatePhaseTtsProjectDialog(
      context: context,
      banks: banks,
    );
    if (result == null) return;

    final id = const Uuid().v4();
    final now = DateTime.now();
    await ref.read(databaseProvider).insertPhaseTtsProject(
          db.PhaseTtsProjectsCompanion(
            id: Value(id),
            name: Value(result.name),
            bankId: Value(result.bankId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    if (mounted) {
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
    if (segments.isEmpty || bankAssets.isEmpty || _generatingAll) return;
    setState(() => _generatingAll = true);
    try {
      for (final seg in segments) {
        if (seg.audioPath != null) continue;
        if (seg.voiceAssetId == null) continue;
        await _generateOne(project, seg, bankAssets);
      }
    } finally {
      if (mounted) setState(() => _generatingAll = false);
    }
  }

  Future<void> _generateOne(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (seg.voiceAssetId == null) return;
    final database = ref.read(databaseProvider);

    setState(() => _generatingSegmentIds.add(seg.id));
    try {
      final providers = await database.getAllProviders();
      final assetMap = {for (final a in bankAssets) a.id: a};
      final providerMap = {for (final p in providers) p.id: p};
      final asset = assetMap[seg.voiceAssetId];
      if (asset == null) return;
      final provider = providerMap[asset.providerId];
      if (provider == null) return;

      final slug = await ref
          .read(storageServiceProvider)
          .ensurePhaseProjectSlug(project.id);
      final outDir = await PathService.instance.phaseTtsDir(slug);

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
    } catch (e) {
      await database.updatePhaseTtsSegment(
        seg.copyWith(error: Value(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _generatingSegmentIds.remove(seg.id));
    }
  }
}
