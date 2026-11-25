import 'role_labels.dart';
import 'direction_controls.dart';
import 'task_profiles_dialog.dart';
import 'scene_summary.dart';
import 'tool_review_controls.dart';
import 'dubbing_intent_fields.dart';
import 'package:neiroha/domain/novel/dubbing_intent.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'model_discover_button.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/data/services/novel/role_model_choice.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

class NovelRoleAnalysisControls extends ConsumerStatefulWidget {
  const NovelRoleAnalysisControls({
    super.key,
    required this.projectId,
    required this.chapterId,
    required this.beforeChange,
    required this.segmentCount,
    this.selectedSegmentId,
  });
  final String projectId;
  final String chapterId;
  final VoidCallback beforeChange;
  final int segmentCount;
  final String? selectedSegmentId;
  @override
  ConsumerState<NovelRoleAnalysisControls> createState() =>
      _NovelRoleAnalysisControlsState();
}

class _NovelRoleAnalysisControlsState
    extends ConsumerState<NovelRoleAnalysisControls> {
  final _model = TextEditingController();
  final _feedback = TextEditingController();
  DubbingMode? _mode;
  String? _providerId;
  TtsCancelToken? _runToken;
  @override
  void dispose() {
    _model.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providers = (ref.watch(ttsProvidersStreamProvider).value ?? [])
        .where(providerOffersLlm)
        .toList();
    final skillConfig = ref.watch(roleSkillConfigurationProvider);
    final defaults = effectiveRoleProfile(
      (skillConfig.value ?? const RoleSkillConfiguration()).active,
      ref.watch(aiCapabilityRouterProvider).value,
    );
    final saved = ref.watch(
      roleAnalysisCheckpointProvider((
        projectId: widget.projectId,
        chapterId: widget.chapterId,
      )),
    );
    if (providers.isEmpty) return Text(l.roleAnalysisOffline);
    final preferred = _providerId ?? defaults.providerId;
    final selected = providers.any((p) => p.id == preferred)
        ? preferred!
        : providers.first.id;
    final checkpoint = saved.value;
    if (_mode == null && !saved.isLoading) {
      final (mode, notes) = readDubbingIntent(checkpoint?.feedback ?? '');
      _mode = mode;
      _feedback.text = notes;
    }
    final intent = dubbingIntent(
      _mode ?? DubbingMode.automatic,
      _feedback.text,
    );
    final changedIntent = checkpoint != null && intent != checkpoint.feedback;
    final needsRoster = checkpoint?.stage == 'rosterReview';
    ref.watch(
      roleReviewSessionProvider((
        projectId: widget.projectId,
        chapterId: widget.chapterId,
      )),
    );
    final roles =
        ref.watch(novelRoleSnapshotProvider(widget.projectId)).value ??
        const NovelRoleSnapshot();
    final service = ref.read(roleAnalysisServiceProvider);
    final analysisRunning =
        _runToken != null || service.isRunning(widget.projectId);
    final running =
        skillConfig.isLoading ||
        saved.isLoading ||
        analysisRunning ||
        ref.read(roleReviewServiceProvider).isRunning(widget.projectId);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.psychology_alt_rounded),
      title: Text(l.roleAnalysisPanelTitle),
      subtitle: checkpoint == null
          ? null
          : Text(roleAnalysisStageLabel(l, checkpoint.stage)),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mode case final mode?)
          DubbingIntentFields(
            mode: mode,
            notes: _feedback,
            enabled: !running,
            onChanged: (value) => setState(() => _mode = value),
            notesChanged: () => setState(() {}),
          ),
        if (needsRoster) Text(l.roleAnalysisRosterHint),
        if (analysisRunning)
          LinearProgressIndicator(
            value:
                checkpoint == null ||
                    widget.segmentCount == 0 ||
                    checkpoint.stage == 'planCast' ||
                    checkpoint.stage == 'replanCast'
                ? null
                : (checkpoint.nextSegment / widget.segmentCount).clamp(
                    0.0,
                    1.0,
                  ),
          ),
        if (checkpoint != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l.phaseRoleProgress(
                checkpoint.nextSegment,
                widget.segmentCount,
                checkpoint.calls,
              ),
            ),
          ),
          if (checkpoint.error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (checkpoint.scene.evidence.isNotEmpty ||
              checkpoint.scene.firstPersonId != null)
            NovelRoleSceneSummary(scene: checkpoint.scene, roles: roles),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (analysisRunning)
              OutlinedButton(
                onPressed: () {
                  _runToken?.cancel();
                  service.pause(widget.projectId);
                },
                child: Text(l.roleAnalysisPause),
              ),
            if (!analysisRunning &&
                checkpoint != null &&
                checkpoint.stage != 'completed')
              FilledButton(
                onPressed: running ? null : () => _run(resume: true),
                child: Text(
                  needsRoster
                      ? l.roleAnalysisApproveRoster
                      : l.roleAnalysisResumeShort,
                ),
              ),
            if (!analysisRunning &&
                (checkpoint == null ||
                    (checkpoint.stage == 'completed' && !changedIntent)))
              FilledButton(
                onPressed: running
                    ? null
                    : () => _run(restart: true, feedback: intent),
                child: Text(
                  checkpoint == null
                      ? l.roleAnalysisStart
                      : l.roleAnalysisRestart,
                ),
              ),
            if (!analysisRunning && changedIntent)
              FilledButton.tonal(
                onPressed: running
                    ? null
                    : () => _run(resume: true, replan: true, feedback: intent),
                child: Text(l.roleAnalysisReplan),
              ),
            if (!analysisRunning &&
                checkpoint != null &&
                (checkpoint.stage != 'completed' || changedIntent))
              TextButton(
                onPressed: running
                    ? null
                    : () => _run(restart: true, feedback: intent),
                child: Text(l.roleAnalysisRestart),
              ),
          ],
        ),
        Text(
          l.roleAnalysisBudget,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.phaseRoleConnectionSettings),
          children: [
            TextButton.icon(
              icon: const Icon(Icons.settings_suggest_rounded),
              label: Text(l.taskProfiles),
              onPressed: running
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => TaskProfilesDialog(
                        projectId: widget.projectId,
                        beforeChange: widget.beforeChange,
                      ),
                    ),
            ),
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.roleAnalysisProvider),
              items: [
                for (final p in providers)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: running
                  ? null
                  : (v) => setState(() => _providerId = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _model,
              enabled: !running,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.roleAnalysisModel,
                hintText: defaults.model,
                suffixIcon: RoleModelDiscoverButton(
                  provider: providers.firstWhere((p) => p.id == selected),
                  enabled: !running,
                  onSelected: (model) => setState(() => _model.text = model),
                ),
              ),
            ),
          ],
        ),
        NovelDirectionControls(
          projectId: widget.projectId,
          chapterId: widget.chapterId,
          provider: providers.firstWhere((p) => p.id == selected),
          model: _model.text.trim().isEmpty
              ? checkpoint?.model ?? defaults.model
              : _model.text.trim(),
          disabled: running,
          beforeChange: widget.beforeChange,
        ),
        NovelToolReviewControls(
          projectId: widget.projectId,
          chapterId: widget.chapterId,
          selectedSegmentId: widget.selectedSegmentId,
          provider: providers.firstWhere((p) => p.id == selected),
          model: _model.text.trim().isEmpty
              ? checkpoint?.model ?? defaults.model
              : _model.text.trim(),
          disabled: running,
          beforeChange: widget.beforeChange,
        ),
      ],
    );
  }

  Future<void> _run({
    bool restart = false,
    bool resume = false,
    bool replan = false,
    String feedback = '',
  }) async {
    final providers = (ref.read(ttsProvidersStreamProvider).value ?? [])
        .where(providerOffersLlm)
        .toList();
    if (providers.isEmpty || _runToken != null) return;
    final service = ref.read(roleAnalysisServiceProvider);
    final token = TtsCancelToken();
    setState(() => _runToken = token);
    try {
      final checkpoint = resume
          ? await service.checkpoints.load(widget.projectId, widget.chapterId)
          : null;
      if (!mounted || token.isCancelled) return;
      final active = ref.read(roleSkillConfigurationProvider).value?.active;
      final router = await ref.read(aiCapabilityRouterProvider.future);
      final defaults = active == null
          ? null
          : effectiveRoleProfile(active, router);
      final providerId =
          checkpoint?.providerId ?? _providerId ?? defaults?.providerId;
      final provider =
          providers.where((p) => p.id == providerId).firstOrNull ??
          providers.first;
      final requestedModel = _model.text.trim();
      final model =
          checkpoint?.model ??
          (requestedModel.isEmpty
              ? defaults?.model ?? 'gpt-6-luna'
              : requestedModel);
      widget.beforeChange();
      await service.run(
        projectId: widget.projectId,
        chapterId: widget.chapterId,
        provider: provider,
        model: model,
        restart: restart,
        confirmRoster: resume,
        replan: replan,
        feedback: feedback,
        cancelToken: token,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _runToken = null);
    }
  }
}
