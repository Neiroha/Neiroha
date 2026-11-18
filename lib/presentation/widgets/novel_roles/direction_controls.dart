import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_direction.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';

class NovelDirectionControls extends ConsumerStatefulWidget {
  const NovelDirectionControls({
    super.key,
    required this.projectId,
    required this.chapterId,
    required this.provider,
    required this.model,
    required this.beforeChange,
    this.disabled = false,
  });
  final String projectId;
  final String chapterId;
  final db.TtsProvider provider;
  final String model;
  final bool disabled;
  final VoidCallback beforeChange;
  @override
  ConsumerState<NovelDirectionControls> createState() =>
      _NovelDirectionControlsState();
}

class _NovelDirectionControlsState
    extends ConsumerState<NovelDirectionControls> {
  TtsCancelToken? _cancellation;
  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profiles =
        ref.watch(novelTaskProfilesProvider(widget.projectId)).value ?? [];
    final enabled = !widget.disabled && _cancellation == null;
    return Column(
      children: [
        Text(l.roleDirectionHelp, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed:
                  enabled &&
                      (widget.model.trim().isNotEmpty ||
                          profiles.any((p) => p.task == ModelTask.casting))
                  ? () => _run(RoleDirectionTask.casting)
                  : null,
              child: Text(l.roleSuggestCast),
            ),
            OutlinedButton(
              onPressed:
                  enabled &&
                      (widget.model.trim().isNotEmpty ||
                          profiles.any((p) => p.task == ModelTask.tone))
                  ? () => _run(RoleDirectionTask.tone)
                  : null,
              child: Text(l.roleSuggestTone),
            ),
            if (_cancellation != null)
              TextButton(
                onPressed: () => _cancellation?.cancel(),
                child: Text(l.uiCancel),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _run(RoleDirectionTask task) async {
    final cancellation = TtsCancelToken();
    setState(() => _cancellation = cancellation);
    final service = ref.read(roleDirectionServiceProvider);
    try {
      final proposal = await service.propose(
        projectId: widget.projectId,
        chapterId: widget.chapterId,
        task: task,
        provider: widget.provider,
        model: widget.model,
        cancellation: cancellation,
      );
      if (!mounted || cancellation.isCancelled) return;
      final roles = ref.read(novelRoleSnapshotProvider(widget.projectId)).value;
      final ids = await showDialog<Set<String>>(
        context: context,
        builder: (_) => _DirectionReview(
          proposal: proposal,
          labels: {
            for (final c in roles?.characters ?? []) c.id: c.name,
            for (final v
                in ref.read(voiceAssetsStreamProvider).value ??
                    <db.VoiceAsset>[])
              v.id: v.name,
            for (final s
                in ref
                        .read(novelSegmentsStreamProvider(widget.projectId))
                        .value ??
                    <db.NovelSegment>[])
              s.id: s.segmentText,
          },
        ),
      );
      if (ids == null || !mounted || cancellation.isCancelled) return;
      widget.beforeChange();
      await service.apply(proposal, ids);
    } on TtsCancelledException {
      // Cancelling a suggestion never writes partial results.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _cancellation = null);
    }
  }
}

class _DirectionReview extends StatefulWidget {
  const _DirectionReview({required this.proposal, required this.labels});
  final RoleDirectionProposal proposal;
  final Map<String, String> labels;
  @override
  State<_DirectionReview> createState() => _DirectionReviewState();
}

class _DirectionReviewState extends State<_DirectionReview> {
  late final _selected = widget.proposal.suggestions.map((s) => s.id).toSet();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.roleDirectionReview),
      content: SizedBox(
        width: 650,
        height: 420,
        child: ListView(
          children: [
            if (widget.proposal.suggestions.isEmpty) Text(l.roleDirectionEmpty),
            for (final s in widget.proposal.suggestions)
              CheckboxListTile(
                value: _selected.contains(s.id),
                title: Text(
                  '${widget.labels[s.id] ?? s.id} → ${widget.labels[s.value] ?? s.value}',
                ),
                subtitle: Text(s.reason),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selected.add(s.id);
                  } else {
                    _selected.remove(s.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text(l.roleApply),
        ),
      ],
    );
  }
}
