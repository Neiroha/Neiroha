import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/presentation/actions/phase_tts/exporter.dart';
import 'package:neiroha/presentation/widgets/phase_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/phase_tts/editor_project_bar.dart';
import 'package:neiroha/presentation/widgets/phase_tts/project_list_header.dart';
import 'package:neiroha/presentation/widgets/phase_tts/segment_voice_panel.dart';
import 'package:neiroha/presentation/widgets/phase_tts/script_workspace.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

typedef PhaseTtsExitGuard = Future<bool> Function();

/// Phase TTS — long-form / novel TTS with project management.
///
/// Editor layout: left column hosts the script editor and split controls;
/// right column hosts sentence-level voice selection and optional per-call
/// generation overrides.
class PhaseTtsScreen extends ConsumerStatefulWidget {
  final ValueChanged<PhaseTtsExitGuard?>? onExitGuardChanged;

  const PhaseTtsScreen({super.key, this.onExitGuardChanged});

  @override
  ConsumerState<PhaseTtsScreen> createState() => _PhaseTtsScreenState();
}

class _PhaseTtsScreenState extends ConsumerState<PhaseTtsScreen> {
  String? _selectedProjectId;
  final _scriptController = TextEditingController();
  bool _generatingAll = false;
  bool _exportingMerged = false;
  bool _dirty = false;
  Future<dynamic> _pendingScriptWrite = Future<dynamic>.value();
  final Set<String> _generatingSegmentIds = <String>{};

  @override
  void initState() {
    super.initState();
    widget.onExitGuardChanged?.call(_confirmLeaveActiveProject);
  }

  @override
  void dispose() {
    widget.onExitGuardChanged?.call(null);
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
                setState(() {
                  _selectedProjectId = id;
                  _dirty = false;
                });
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

    final segments = segmentsAsync.valueOrNull ?? const <db.PhaseTtsSegment>[];
    final hasGeneratedAudio = segments.any(
      (s) => s.audioPath != null && !s.missing,
    );

    return Column(
      children: [
        EditorProjectBar(
          project: project,
          voiceCount: bankAssets.length,
          exporting: _exportingMerged,
          dirty: _dirty,
          onExportMerged: hasGeneratedAudio
              ? () => unawaited(_exportMerged(project, segments))
              : null,
          onClose: () => unawaited(_back(project)),
          onSave: () => unawaited(_saveProject(project)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.55,
            left: PhaseScriptWorkspace(
              controller: _scriptController,
              onScriptChanged: () => _saveScript(project),
              onAutoSplit: (rule) => _autoSplit(project, rule),
            ),
            rightBuilder: (_) => _buildRightPane(
              project: project,
              segments: segments,
              bankAssets: bankAssets,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPane({
    required db.PhaseTtsProject project,
    required List<db.PhaseTtsSegment> segments,
    required List<db.VoiceAsset> bankAssets,
  }) {
    return SegmentVoicePanel(
      project: project,
      segments: segments,
      bankAssets: bankAssets,
      generatingSegmentIds: _generatingSegmentIds,
      onApplyVoiceToAll: (voiceId) =>
          _applyVoiceToAll(project, segments, voiceId),
      onVoiceChanged: (segment, voiceId) =>
          _updateSegmentVoice(segment, voiceId),
      onPlay: (segment, index) => _playSegment(segment, index, bankAssets),
      onGenerate: bankAssets.isEmpty
          ? null
          : (segment) => _generateOne(project, segment, bankAssets),
      onDelete: (id) {
        _markDirty();
        unawaited(ref.read(databaseProvider).deletePhaseTtsSegment(id));
      },
      onChanged: _markDirty,
      onPlayAll: () => unawaited(_playAll(segments, bankAssets)),
      onGenerateAll: () =>
          unawaited(_generateAll(project, segments, bankAssets)),
      generatingAll: _generatingAll,
    );
  }

  void _markDirty() {
    if (_dirty || !mounted) return;
    setState(() => _dirty = true);
  }

  Future<void> _saveProject(db.PhaseTtsProject project) async {
    await _pendingScriptWrite;
    await ref
        .read(databaseProvider)
        .updatePhaseTtsProject(
          project.copyWith(
            scriptText: _scriptController.text,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    setState(() => _dirty = false);
    _showSnack('Saved');
  }

  Future<bool> _back(db.PhaseTtsProject project) async {
    final canLeave = await _confirmLeave(project);
    if (canLeave && mounted) {
      setState(() {
        _selectedProjectId = null;
        _dirty = false;
      });
    }
    return canLeave;
  }

  Future<bool> _confirmLeaveActiveProject() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return true;
    final project = await ref
        .read(databaseProvider)
        .getPhaseTtsProjectById(projectId);
    if (project == null) return true;
    return _confirmLeave(project);
  }

  Future<bool> _confirmLeave(db.PhaseTtsProject project) async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes in this project. Save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text("Don't save"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await _saveProject(project);
      return true;
    }
    return choice == 'discard';
  }

  // ───────────────── Actions ─────────────────

  void _playSegment(
    db.PhaseTtsSegment seg,
    int index,
    List<db.VoiceAsset> bankAssets,
  ) {
    if (seg.audioPath == null || !File(seg.audioPath!).existsSync()) return;
    final voiceName =
        bankAssets.where((a) => a.id == seg.voiceAssetId).firstOrNull?.name ??
        'Segment ${index + 1}';
    ref
        .read(playbackNotifierProvider.notifier)
        .load(
          seg.audioPath!,
          seg.segmentText,
          subtitle: voiceName,
          sourceTag: phaseTtsPlaybackSource,
        );
  }

  Future<void> _playAll(
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) async {
    final ordered = [...segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final assetMap = {for (final asset in bankAssets) asset.id: asset};
    final items = [
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].audioPath != null &&
            !ordered[i].missing &&
            File(ordered[i].audioPath!).existsSync())
          (
            audioPath: ordered[i].audioPath!,
            title: ordered[i].segmentText,
            subtitle:
                assetMap[ordered[i].voiceAssetId]?.name ?? 'Segment ${i + 1}',
          ),
    ];
    if (items.isEmpty) {
      _showSnack('No generated audio to play.');
      return;
    }
    await ref.read(playbackNotifierProvider.notifier).playSequenceFrom(
          items,
          sourceTag: phaseTtsPlaybackSource,
        );
  }

  void _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).valueOrNull ?? const [];
    if (banks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a Voice Bank first')),
        );
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
    await ref
        .read(databaseProvider)
        .insertPhaseTtsProject(
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
        _dirty = false;
        _scriptController.clear();
      });
    }
  }

  void _saveScript(db.PhaseTtsProject project) {
    _markDirty();
    // Autosave the text itself; the Save button confirms the edit and bumps
    // updatedAt so the project moves in the list.
    final database = ref.read(databaseProvider);
    final nextProject = project.copyWith(scriptText: _scriptController.text);
    _pendingScriptWrite = _pendingScriptWrite.catchError((_) {}).then((_) {
      return database.updatePhaseTtsProject(nextProject);
    });
  }

  Future<void> _autoSplit(db.PhaseTtsProject project, SplitRule rule) async {
    final text = _scriptController.text;
    if (text.trim().isEmpty) return;
    _markDirty();

    final database = ref.read(databaseProvider);
    await database.clearPhaseTtsSegments(project.id);
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(project.id);
    await ref.read(phaseSegmentSettingsFileServiceProvider).delete(slug);
    final segments = applySplitRule(rule, text);

    for (var i = 0; i < segments.length; i++) {
      await database.insertPhaseTtsSegment(
        db.PhaseTtsSegmentsCompanion(
          id: Value(const Uuid().v4()),
          projectId: Value(project.id),
          orderIndex: Value(i),
          segmentText: Value(segments[i]),
        ),
      );
    }
  }

  Future<void> _applyVoiceToAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> currentSegments,
    String? voiceId,
  ) async {
    final database = ref.read(databaseProvider);
    final segments = currentSegments.isEmpty
        ? await database.getPhaseTtsSegments(project.id)
        : currentSegments;
    for (final segment in segments) {
      await database.updatePhaseTtsSegment(
        segment.copyWith(voiceAssetId: Value(voiceId)),
      );
    }
    _markDirty();
  }

  Future<void> _updateSegmentVoice(
    db.PhaseTtsSegment segment,
    String? voiceId,
  ) async {
    await ref
        .read(databaseProvider)
        .updatePhaseTtsSegment(segment.copyWith(voiceAssetId: Value(voiceId)));
    _markDirty();
  }

  Future<PhaseSegmentSettings> _loadSegmentSettings(
    db.PhaseTtsProject project,
  ) async {
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(project.id);
    return ref.read(phaseSegmentSettingsFileServiceProvider).load(slug);
  }

  Future<void> _generateAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (segments.isEmpty || bankAssets.isEmpty || _generatingAll) return;
    setState(() => _generatingAll = true);
    try {
      final segmentSettings = await _loadSegmentSettings(project);
      for (final seg in segments) {
        if (seg.audioPath != null) continue;
        if (seg.voiceAssetId == null) continue;
        await _generateOne(
          project,
          seg,
          bankAssets,
          segmentSettings: segmentSettings,
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAll = false);
    }
  }

  Future<void> _generateOne(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets, {
    PhaseSegmentSettings? segmentSettings,
  }) async {
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

      final settings = segmentSettings ?? await _loadSegmentSettings(project);
      final overrides = settings.bySegmentId[seg.id];
      final instructionOverride = overrides?.voiceInstruction?.trim();
      final audioTagPrefix = overrides?.audioTagPrefix?.trim();
      final slug = await ref
          .read(storageServiceProvider)
          .ensurePhaseProjectSlug(project.id);
      final outDir = await PathService.instance.phaseTtsDir(slug);

      final adapter = createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(
        TtsRequest(
          text: seg.segmentText,
          voice: asset.presetVoiceName ?? asset.name,
          speed: asset.speed,
          textLang: provider.adapterType == 'gptSovits'
              ? asset.modelName
              : null,
          presetVoiceName: asset.presetVoiceName,
          voiceInstruction: _supportsVoiceInstruction(asset, provider)
              ? (instructionOverride == null || instructionOverride.isEmpty
                    ? asset.voiceInstruction
                    : instructionOverride)
              : null,
          audioTagPrefix: _supportsAudioTags(asset, provider)
              ? (audioTagPrefix == null || audioTagPrefix.isEmpty
                    ? null
                    : audioTagPrefix)
              : null,
          refAudioPath: asset.refAudioPath,
          promptText: asset.promptText,
          promptLang: asset.promptLang,
        ),
      );
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
      _markDirty();
    } catch (e) {
      await database.updatePhaseTtsSegment(
        seg.copyWith(error: Value(e.toString())),
      );
      _markDirty();
    } finally {
      if (mounted) setState(() => _generatingSegmentIds.remove(seg.id));
    }
  }

  bool _supportsVoiceInstruction(
    db.VoiceAsset asset,
    db.TtsProvider provider,
  ) {
    return switch (provider.adapterType) {
      'chatCompletionsTts' => _isMimoTtsModel(asset, provider),
      'cosyvoice' => true,
      'voxcpm2Native' => true,
      'geminiTts' => true,
      _ => false,
    };
  }

  bool _supportsAudioTags(db.VoiceAsset asset, db.TtsProvider provider) {
    return _isMimoTtsModel(asset, provider);
  }

  bool _isMimoTtsModel(db.VoiceAsset asset, db.TtsProvider provider) {
    final model = (asset.modelName ?? provider.defaultModelName).toLowerCase();
    return provider.adapterType == 'chatCompletionsTts' &&
        model.contains('mimo') &&
        (model.contains('tts') ||
            model.contains('voiceclone') ||
            model.contains('voicedesign'));
  }

  Future<void> _exportMerged(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
  ) async {
    setState(() => _exportingMerged = true);
    try {
      await exportPhaseTtsMergedAudio(
        context: context,
        ref: ref,
        project: project,
        segments: segments,
      );
    } finally {
      if (mounted) setState(() => _exportingMerged = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
