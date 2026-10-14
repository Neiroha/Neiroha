import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/voice_capabilities.dart';
import 'package:neiroha/presentation/actions/phase_tts/exporter.dart';
import 'package:neiroha/presentation/actions/voice_health_warning.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/widgets/phase_tts/create_project_dialog.dart';
import 'package:neiroha/presentation/widgets/phase_tts/editor_project_bar.dart';
import 'package:neiroha/presentation/widgets/phase_tts/merge_settings_dialog.dart';
import 'package:neiroha/presentation/widgets/phase_tts/project_list_header.dart';
import 'package:neiroha/presentation/widgets/phase_tts/segment_voice_panel.dart';
import 'package:neiroha/presentation/widgets/phase_tts/script_workspace.dart';
import 'package:neiroha/presentation/widgets/loudness_normalize_dialog.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/project_settings_dialog.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
  final _scriptController = ScriptHighlightController();
  bool _generatingAll = false;
  TtsCancelToken? _cancelToken;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppBackIntent.markChildHandled();
          unawaited(_backActiveProject());
        }
      },
      child: _buildProjectContent(),
    );
  }

  // ───────────────── List mode (card grid) ─────────────────

  Widget _buildProjectListScreen() {
    final projectsAsync = ref.watch(phaseTtsProjectsStreamProvider);
    final banks =
        ref.watch(voiceBanksStreamProvider).value ?? const <db.VoiceBank>[];
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
              onSettings: (card) => unawaited(
                _showProjectSettings(
                  projects.where((p) => p.id == card.id).firstOrNull,
                  banks,
                ),
              ),
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

  Future<void> _showProjectSettings(
    db.PhaseTtsProject? project,
    List<db.VoiceBank> banks,
  ) async {
    if (project == null) return;
    final result = await showProjectSettingsDialog(
      context: context,
      projectName: project.name,
      bankId: project.bankId,
      banks: banks,
      autoNormalizeLoudness: project.autoNormalizeLoudness,
    );
    if (result == null) return;
    final database = ref.read(databaseProvider);
    if (result.deleteRequested) {
      await database.deletePhaseTtsProject(project.id);
      return;
    }
    final bankChanged = result.bankId != project.bankId;
    if (result.name != project.name ||
        bankChanged ||
        result.autoNormalizeLoudness != project.autoNormalizeLoudness) {
      await database.updatePhaseTtsProject(
        project.copyWith(
          name: result.name,
          bankId: result.bankId,
          autoNormalizeLoudness: result.autoNormalizeLoudness,
          updatedAt: DateTime.now(),
        ),
      );
      if (bankChanged) {
        await _clearPhaseProjectVoiceAssignments(project.id);
      }
    }
  }

  Future<void> _clearPhaseProjectVoiceAssignments(String projectId) async {
    final database = ref.read(databaseProvider);
    final segments = await database.getPhaseTtsSegments(projectId);
    for (final segment in segments) {
      await database.updatePhaseTtsSegment(
        segment.copyWith(
          voiceAssetId: const Value(null),
          audioPath: const Value(null),
          audioDuration: const Value(null),
          error: const Value(null),
          missing: false,
        ),
      );
    }
  }

  // ───────────────── Editor mode ─────────────────

  Widget _buildProjectContent() {
    final projectId = _selectedProjectId!;
    final projectsAsync = ref.watch(phaseTtsProjectsStreamProvider);
    final segmentsAsync = ref.watch(phaseTtsSegmentsStreamProvider(projectId));
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    final project = projectsAsync.value
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    if (project == null) {
      return Center(child: CircularProgressIndicator());
    }

    final membersAsync = ref.watch(bankMembersStreamProvider(project.bankId));
    final bankMembers = membersAsync.value ?? [];
    final allAssets = assetsAsync.value ?? [];
    final assetMap = {for (final a in allAssets) a.id: a};
    final bankAssets = bankMembers
        .map((m) => assetMap[m.voiceAssetId])
        .whereType<db.VoiceAsset>()
        .toList();

    final segments = segmentsAsync.value ?? const <db.PhaseTtsSegment>[];
    final hasGeneratedAudio = segments.any(
      (s) => s.audioPath != null && !s.missing,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            unawaited(_saveProject(project)),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            unawaited(_saveProject(project)),
      },
      child: Column(
        children: [
          EditorProjectBar(
            project: project,
            voiceCount: bankAssets.length,
            exporting: _exportingMerged,
            dirty: _dirty,
            onExportMerged: hasGeneratedAudio
                ? () => unawaited(_exportMerged(project, segments))
                : null,
            onMergeSettings: () => unawaited(_showMergeSettings(project)),
            onClose: () => unawaited(_back(project)),
            onSave: () => unawaited(_saveProject(project)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ResizableSplitPane(
              initialLeftFraction: 0.55,
              compactRightIcon: Icons.tune_rounded,
              compactRightLabel: AppLocalizations.of(context).uiDetails,
              left: PhaseScriptWorkspace(
                controller: _scriptController,
                onScriptChanged: () => _saveScript(project),
                onAutoSplit: (rule) =>
                    unawaited(_autoSplit(project, rule, segments)),
              ),
              rightBuilder: (_) => _buildRightPane(
                project: project,
                segments: segments,
                bankAssets: bankAssets,
              ),
            ),
          ),
        ],
      ),
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
      onGenerateMany: bankAssets.isEmpty
          ? null
          : (targets) =>
                unawaited(_generateBatch(project, targets, bankAssets)),
      onCancelGenerate: _cancelToken?.cancel,
      onDelete: (rows) => unawaited(_deleteSegments(project, rows)),
      onEditText: _editSegmentText,
      onSplit: (segment, head, tail) async {
        await ref
            .read(databaseProvider)
            .splitPhaseSegment(segment, head, tail, const Uuid().v4());
        _markDirty();
      },
      onMergeNext: (segment) async {
        await ref
            .read(databaseProvider)
            .mergePhaseSegmentWithNext(project.id, segment.id);
        _markDirty();
      },
      onInsertAfter: (after, text) async {
        await ref
            .read(databaseProvider)
            .insertPhaseSegmentAfter(
              projectId: project.id,
              afterId: after?.id,
              id: const Uuid().v4(),
              text: text,
              voiceAssetId: after?.voiceAssetId,
            );
        _markDirty();
      },
      onReorder: (oldIndex, newIndex) {
        _markDirty();
        unawaited(
          ref
              .read(databaseProvider)
              .reorderPhaseSegment(project.id, oldIndex, newIndex),
        );
      },
      onReveal: (segment) => _revealInScript(segment, segments),
      onChanged: _markDirty,
      onPlayAll: () => unawaited(_playAll(project, segments, bankAssets)),
      onGenerateAll: () =>
          unawaited(_generateAll(project, segments, bankAssets)),
      onNormalize: _generatingAll || _generatingSegmentIds.isNotEmpty
          ? null
          : () => unawaited(_normalizeLoudness(project, segments)),
      generatingAll: _generatingAll,
    );
  }

  /// Delete with a snackbar undo that puts the rows back in place.
  Future<void> _deleteSegments(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> rows,
  ) async {
    if (rows.isEmpty) return;
    final database = ref.read(databaseProvider);
    await database.deletePhaseSegments(project.id, rows.map((s) => s.id));
    _markDirty();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.phaseDeletedCount(rows.length)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.phaseUndo,
          onPressed: () =>
              unawaited(database.restorePhaseSegments(project.id, rows)),
        ),
      ),
    );
  }

  /// Highlight [segment] inside the script. Segments are located in order,
  /// each search starting where the previous one ended, so repeated
  /// sentences resolve to the right occurrence.
  void _revealInScript(
    db.PhaseTtsSegment segment,
    List<db.PhaseTtsSegment> segments,
  ) {
    final script = _scriptController.text;
    final ordered = [...segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    var cursor = 0;
    for (final s in ordered) {
      final needle = s.segmentText.trim();
      if (needle.isEmpty) continue;
      final at = script.indexOf(needle, cursor);
      if (s.id == segment.id) {
        // Fall back to a global search when earlier segments were edited.
        final hit = at >= 0 ? at : script.indexOf(needle);
        if (hit < 0) {
          _scriptController.clearHighlight();
        } else {
          _scriptController.reveal(
            TextRange(start: hit, end: hit + needle.length),
          );
        }
        return;
      }
      if (at >= 0) cursor = at + needle.length;
    }
  }

  Future<void> _showMergeSettings(db.PhaseTtsProject project) async {
    final result = await showPhaseMergeSettingsDialog(
      context: context,
      project: project,
    );
    if (result == null) return;
    await ref.read(databaseProvider).updatePhaseTtsProject(result);
  }

  Future<void> _editSegmentText(db.PhaseTtsSegment segment, String text) async {
    // The old take no longer matches the words; drop the link so the
    // segment shows up as pending again (the file itself stays on disk).
    await ref
        .read(databaseProvider)
        .updatePhaseTtsSegment(
          segment.copyWith(
            segmentText: text,
            audioPath: const Value(null),
            audioDuration: const Value(null),
            error: const Value(null),
            missing: false,
          ),
        );
    _markDirty();
  }

  Future<void> _normalizeLoudness(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
  ) async {
    await runLoudnessNormalization(
      context: context,
      ref: ref,
      bankId: project.bankId,
      items: [
        for (final s in segments)
          if (s.audioPath != null && !s.missing)
            LoudnessItem(
              id: s.id,
              path: s.audioPath!,
              voiceAssetId: s.voiceAssetId,
            ),
      ],
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
    _showSnack(AppLocalizations.of(context).uiSaved);
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

  Future<void> _backActiveProject() async {
    final projectId = _selectedProjectId;
    if (projectId == null) return;
    final project = await ref
        .read(databaseProvider)
        .getPhaseTtsProjectById(projectId);
    if (project == null) {
      if (mounted) setState(() => _selectedProjectId = null);
      return;
    }
    await _back(project);
  }

  Future<bool> _confirmLeave(db.PhaseTtsProject project) async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiUnsavedChanges),
        content: Text(
          AppLocalizations.of(
            context,
          ).uiYouHaveUnsavedChangesInThisProjectSaveBeforeLeaving,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(AppLocalizations.of(context).uiDontSave),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(AppLocalizations.of(context).uiSaveLeave),
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
    db.PhaseTtsProject project,
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
      _showSnack(AppLocalizations.of(context).phaseNoAudioToPlay);
      return;
    }
    await ref
        .read(playbackNotifierProvider.notifier)
        .playSequenceFrom(
          items,
          sourceTag: phaseTtsPlaybackSource,
          gap: Duration(milliseconds: (project.mergeGapSeconds * 1000).round()),
        );
  }

  void _createProject() async {
    final banks = ref.read(voiceBanksStreamProvider).value ?? const [];
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

  Future<void> _autoSplit(
    db.PhaseTtsProject project,
    SplitRule rule,
    List<db.PhaseTtsSegment> existing,
  ) async {
    final text = _scriptController.text;
    if (text.trim().isEmpty) return;
    if (existing.isNotEmpty && !await _confirmResplit(existing.length)) return;
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

  Future<bool> _confirmResplit(int count) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.phaseResplitTitle),
        content: Text(l10n.phaseResplitBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.phaseResplitConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
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

  /// Generate every pending segment that has a voice.
  Future<void> _generateAll(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> segments,
    List<db.VoiceAsset> bankAssets,
  ) => _generateBatch(project, [
    for (final seg in segments)
      if (seg.audioPath == null && seg.voiceAssetId != null) seg,
  ], bankAssets);

  /// Generate [targets] (regenerating ones that already have audio) under a
  /// shared cancel token so "Stop" drops whatever has not started yet.
  Future<void> _generateBatch(
    db.PhaseTtsProject project,
    List<db.PhaseTtsSegment> targets,
    List<db.VoiceAsset> bankAssets,
  ) async {
    if (targets.isEmpty || bankAssets.isEmpty || _generatingAll) return;
    final token = TtsCancelToken();
    setState(() {
      _generatingAll = true;
      _cancelToken = token;
    });
    try {
      final segmentSettings = await _loadSegmentSettings(project);
      await Future.wait([
        for (final seg in targets)
          _generateOne(
            project,
            seg,
            bankAssets,
            segmentSettings: segmentSettings,
            cancelToken: token,
          ),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _generatingAll = false;
          _cancelToken = null;
        });
      }
    }
  }

  Future<void> _generateOne(
    db.PhaseTtsProject project,
    db.PhaseTtsSegment seg,
    List<db.VoiceAsset> bankAssets, {
    PhaseSegmentSettings? segmentSettings,
    TtsCancelToken? cancelToken,
  }) async {
    if (seg.voiceAssetId == null) return;
    if (cancelToken?.isCancelled ?? false) return;
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
      if (mounted) {
        warnIfVoiceHealthFailedOnce(context: context, ref: ref, asset: asset);
      }

      final settings = segmentSettings ?? await _loadSegmentSettings(project);
      final overrides = settings.bySegmentId[seg.id];
      final instructionOverride = overrides?.voiceInstruction?.trim();
      final audioTagPrefix = overrides?.audioTagPrefix?.trim();
      final slug = await ref
          .read(storageServiceProvider)
          .ensurePhaseProjectSlug(project.id);
      final outDir = await PathService.instance.phaseTtsDir(slug);

      final result = await ref
          .read(ttsQueueServiceProvider)
          .synthesize(
            provider: provider,
            modelName: asset.modelName,
            source: 'Phase TTS',
            label: 'Segment ${seg.orderIndex + 1}: ${seg.segmentText}',
            cancelToken: cancelToken,
            request: TtsRequest(
              text: seg.segmentText,
              voice: asset.presetVoiceName ?? asset.name,
              speed: asset.speed,
              textLang: provider.adapterType == 'gptSovits'
                  ? asset.modelName
                  : null,
              presetVoiceName: asset.presetVoiceName,
              voiceInstruction:
                  VoiceCapabilities.supportsVoiceInstruction(asset, provider)
                  ? (instructionOverride == null || instructionOverride.isEmpty
                        ? asset.voiceInstruction
                        : instructionOverride)
                  : null,
              audioTagPrefix:
                  VoiceCapabilities.supportsAudioTags(asset, provider)
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
      await ref
          .read(autoLoudnessServiceProvider)
          .normalizeGenerated(
            enabled: project.autoNormalizeLoudness,
            path: filePath,
            bankId: project.bankId,
            voiceAssetId: asset.id,
          );
      final durationSec = await measureAudioDuration(filePath);
      await database.updatePhaseTtsSegment(
        seg.copyWith(
          audioPath: Value(filePath),
          audioDuration: Value(durationSec),
          error: const Value(null),
        ),
      );
      _markDirty();
    } on TtsCancelledException {
      // Stopped before it started: leave the segment pending.
    } catch (e) {
      await database.updatePhaseTtsSegment(
        seg.copyWith(error: Value(e.toString())),
      );
      _markDirty();
    } finally {
      if (mounted) setState(() => _generatingSegmentIds.remove(seg.id));
    }
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
