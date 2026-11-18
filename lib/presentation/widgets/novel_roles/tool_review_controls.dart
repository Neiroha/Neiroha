import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_review.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'tool_review_dialog.dart';

class NovelToolReviewControls extends ConsumerStatefulWidget {
  const NovelToolReviewControls({
    super.key,
    required this.projectId,
    required this.chapterId,
    required this.provider,
    required this.model,
    required this.disabled,
    required this.beforeChange,
    this.selectedSegmentId,
  });
  final String projectId, chapterId, model;
  final String? selectedSegmentId;
  final db.TtsProvider provider;
  final bool disabled;
  final VoidCallback beforeChange;
  @override
  ConsumerState<NovelToolReviewControls> createState() =>
      _NovelToolReviewControlsState();
}

class _NovelToolReviewControlsState
    extends ConsumerState<NovelToolReviewControls> {
  bool _busy = false, _currentOnly = true;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = ref
        .watch(
          roleReviewSessionProvider((
            projectId: widget.projectId,
            chapterId: widget.chapterId,
          )),
        )
        .value;
    final service = ref.read(roleReviewServiceProvider);
    final running = _busy || service.isRunning(widget.projectId);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(l.roleToolReview),
      children: [
        Text(l.roleToolBudget, style: Theme.of(context).textTheme.bodySmall),
        if (widget.selectedSegmentId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_currentOnly ? l.roleToolCurrent : l.roleToolDoubts),
            value: _currentOnly,
            onChanged: running || widget.disabled
                ? null
                : (v) => setState(() => _currentOnly = v),
          ),
        if (saved != null) ...[
          Text('${_status(l, saved.status)} · ${saved.model}'),
          Text(
            '${saved.calls}/${saved.budget.maxCalls} ${l.roleAnalysisCalls} · ${l.roleToolReserved}: ${saved.chargedTokens}/${saved.budget.maxTokens} · ${(saved.elapsedMs / 1000).toStringAsFixed(1)} s',
          ),
          if (saved.summary.isNotEmpty) Text(saved.summary),
          if (saved.error != null)
            Text(
              saved.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: running || widget.disabled ? null : () => _run(false),
              child: Text(l.roleToolStart),
            ),
            if (!running && saved?.canResume == true)
              TextButton(
                onPressed: widget.disabled ? null : () => _run(true),
                child: Text(l.roleAnalysisResume),
              ),
            if (running)
              TextButton(
                onPressed: () => service.pause(widget.projectId),
                child: Text(l.roleAnalysisPause),
              ),
            if (saved?.canApply == true)
              TextButton(
                onPressed: running || widget.disabled
                    ? null
                    : () => _review(saved!),
                child: Text(l.roleToolReviewProposals),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _run(bool resume) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(roleReviewServiceProvider);
      final previous = resume
          ? await service.repository.load(widget.projectId, widget.chapterId)
          : null;
      final providers = ref.read(ttsProvidersStreamProvider).value ?? [];
      final provider = resume
          ? providers.where((p) => p.id == previous?.providerId).firstOrNull
          : widget.provider;
      if (provider == null) {
        throw StateError('The saved provider is unavailable.');
      }
      await service.run(
        projectId: widget.projectId,
        chapterId: widget.chapterId,
        provider: provider,
        model: previous?.model ?? widget.model,
        resume: resume,
        targetIds: _currentOnly && widget.selectedSegmentId != null
            ? [widget.selectedSegmentId!]
            : null,
      );
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(RoleReviewSession session) async {
    setState(() => _busy = true);
    try {
      final roles = await ref
          .read(characterRepositoryProvider)
          .load(widget.projectId);
      final segments = await ref
          .read(databaseProvider)
          .getNovelSegments(widget.projectId);
      if (!mounted) return;
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (_) => NovelToolReviewDialog(
          session: session,
          roles: roles,
          segments: segments,
        ),
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      widget.beforeChange();
      await ref
          .read(roleReviewServiceProvider)
          .repository
          .apply(widget.projectId, widget.chapterId, session.id, selected);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  String _status(AppLocalizations l, String value) => switch (value) {
    'ready' => l.roleToolReady,
    'running' => l.roleToolReview,
    'budgetExhausted' => l.roleToolBudgetExhausted,
    'applied' => l.roleToolApplied,
    'failed' => l.roleStageFailed,
    _ => l.roleStagePaused,
  };
}
