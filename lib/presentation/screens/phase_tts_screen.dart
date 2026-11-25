import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/ai/core/tts_adapter.dart';
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
import 'package:neiroha/presentation/widgets/phase_tts/role_assignment_button.dart';
import 'package:neiroha/presentation/widgets/loudness_normalize_dialog.dart';
import 'package:neiroha/presentation/widgets/project_card_grid.dart';
import 'package:neiroha/presentation/widgets/project_settings_dialog.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part '../widgets/phase_tts/phase_editor_actions.dart';
part '../widgets/phase_tts/phase_editor_generation.dart';

typedef PhaseTtsExitGuard = Future<bool> Function();

/// Long-text editor with splitting, shared role AI and voice generation.
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

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

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
                    subtitle: phaseScriptPreview(p.scriptText),
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
                roleAction: PhaseRoleAssignmentButton(
                  projectId: project.id,
                  controller: _scriptController,
                  enabled: !_generatingAll && _generatingSegmentIds.isEmpty,
                  prepare: () async {
                    await _pendingScriptWrite;
                  },
                  beforeApply: () async {
                    await ref.read(playbackNotifierProvider.notifier).stop();
                    _markDirty();
                  },
                ),
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
}
