import 'role_labels.dart';
import 'direction_controls.dart';
import 'task_profiles_dialog.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/presentation/widgets/model_capability_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

class NovelRoleAnalysisControls extends ConsumerStatefulWidget {
  const NovelRoleAnalysisControls({
    super.key,
    required this.projectId,
    required this.chapterId,
    required this.beforeChange,
  });
  final String projectId;
  final String chapterId;
  final VoidCallback beforeChange;
  @override
  ConsumerState<NovelRoleAnalysisControls> createState() =>
      _NovelRoleAnalysisControlsState();
}

class _NovelRoleAnalysisControlsState
    extends ConsumerState<NovelRoleAnalysisControls> {
  final _model = TextEditingController();
  final _feedback = TextEditingController();
  String? _providerId;
  bool _busy = false;
  @override
  void dispose() {
    _model.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providers = ref.watch(ttsProvidersStreamProvider).value ?? [];
    final saved = ref.watch(
      roleAnalysisCheckpointProvider((
        projectId: widget.projectId,
        chapterId: widget.chapterId,
      )),
    );
    if (providers.isEmpty) return Text(l.roleAnalysisOffline);
    final selected = providers.any((p) => p.id == _providerId)
        ? _providerId!
        : providers.first.id;
    final checkpoint = saved.value;
    final running =
        _busy ||
        ref.read(roleAnalysisServiceProvider).isRunning(widget.projectId);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l.roleAnalysisStart),
      children: [
        TextButton.icon(
          icon: const Icon(Icons.settings_suggest),
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
          onChanged: running ? null : (v) => setState(() => _providerId = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          enabled: !running,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l.roleAnalysisModel,
            suffixIcon: IconButton(
              tooltip: l.modelDiscover,
              icon: const Icon(Icons.manage_search),
              onPressed: _busy
                  ? null
                  : () async {
                      final value = await showDialog<String>(
                        context: context,
                        builder: (_) => ModelCapabilityPicker(
                          provider: providers.firstWhere(
                            (p) => p.id == selected,
                          ),
                          route: ServiceRoute.chatCompletions,
                          feature: 'text',
                        ),
                      );
                      if (mounted && value != null) {
                        setState(() => _model.text = value);
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.roleAnalysisBudget,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        NovelDirectionControls(
          projectId: widget.projectId,
          chapterId: widget.chapterId,
          provider: providers.firstWhere((p) => p.id == selected),
          model: _model.text.trim().isEmpty
              ? checkpoint?.model ?? ''
              : _model.text.trim(),
          disabled: running,
          beforeChange: widget.beforeChange,
        ),
        if (checkpoint != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${roleAnalysisStageLabel(l, checkpoint.stage)} · ${checkpoint.nextSegment} ${l.roleAnalysisSentences} · ${checkpoint.calls} ${l.roleAnalysisCalls} · ${checkpoint.model}',
            ),
          ),
        if (checkpoint?.error != null)
          Text(
            checkpoint!.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: running ? null : () => _run(restart: true),
          child: Text(l.roleAnalysisStart),
        ),
        if (checkpoint != null && checkpoint.stage != 'completed')
          OutlinedButton(
            onPressed: running ? null : () => _run(resume: true),
            child: Text(l.roleAnalysisResume),
          ),
        if (running)
          OutlinedButton(
            onPressed: () =>
                ref.read(roleAnalysisServiceProvider).pause(widget.projectId),
            child: Text(l.roleAnalysisPause),
          ),
        TextField(
          controller: _feedback,
          enabled: !running,
          decoration: InputDecoration(labelText: l.roleAnalysisFeedback),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () =>
                    _run(resume: checkpoint != null, feedback: _feedback.text),
          child: Text(l.roleAnalysisReplan),
        ),
      ],
    );
  }

  Future<void> _run({
    bool restart = false,
    bool resume = false,
    String feedback = '',
  }) async {
    final providers = ref.read(ttsProvidersStreamProvider).value ?? [];
    if (providers.isEmpty) return;
    final service = ref.read(roleAnalysisServiceProvider);
    final checkpoint = resume
        ? await service.checkpoints.load(widget.projectId, widget.chapterId)
        : null;
    if (!mounted) return;
    final provider =
        providers
            .where((p) => p.id == (checkpoint?.providerId ?? _providerId))
            .firstOrNull ??
        providers.first;
    final model = checkpoint?.model ?? _model.text.trim();
    widget.beforeChange();
    setState(() => _busy = true);
    try {
      await service.run(
        projectId: widget.projectId,
        chapterId: widget.chapterId,
        provider: provider,
        model: model,
        restart: restart,
        confirmRoster: resume,
        feedback: feedback,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
