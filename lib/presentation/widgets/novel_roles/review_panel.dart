import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

import 'annotation_editor.dart';
import 'character_list.dart';
import 'analysis_controls.dart';
import 'structure_tools.dart';
import 'character_tools.dart';

class NovelRoleReviewPanel extends ConsumerStatefulWidget {
  const NovelRoleReviewPanel({
    super.key,
    required this.projectId,
    required this.roles,
    required this.assets,
    required this.segments,
    required this.beforeChange,
    required this.onSelect,
    required this.onPreview,
    this.selected,
    this.chapterId,
  });
  final String projectId;
  final String? chapterId;
  final NovelRoleSnapshot roles;
  final List<db.VoiceAsset> assets;
  final List<db.NovelSegment> segments;
  final db.NovelSegment? selected;
  final VoidCallback beforeChange;
  final ValueChanged<db.NovelSegment> onSelect;
  final ValueChanged<db.NovelSegment> onPreview;

  @override
  ConsumerState<NovelRoleReviewPanel> createState() =>
      _NovelRoleReviewPanelState();
}

class _NovelRoleReviewPanelState extends ConsumerState<NovelRoleReviewPanel> {
  bool _onlyUncertain = true;
  int _shown = 12;

  @override
  void didUpdateWidget(covariant NovelRoleReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId) _shown = 12;
  }

  @override
  Widget build(BuildContext context) {
    final NovelRoleReviewPanel(
      :projectId,
      :chapterId,
      :roles,
      :assets,
      :segments,
      :beforeChange,
      :onSelect,
      :onPreview,
      :selected,
    ) = widget;
    final l = AppLocalizations.of(context);
    final chapterSegments = segments
        .where((s) => s.chapterId == chapterId)
        .toList();
    final pending = chapterSegments.where((s) {
      final a = roles.annotations[s.id];
      if (a?.locked == true) return false;
      if (a == null || a.textRevision != novelTextRevision(s.segmentText)) {
        return true;
      }
      return a.reviewState == NovelReviewState.pending ||
          a.reviewState == NovelReviewState.conflict ||
          (!_onlyUncertain && a.reviewState == NovelReviewState.inferred);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (chapterId != null)
          NovelRoleAnalysisControls(
            key: ValueKey('$projectId:$chapterId'),
            projectId: projectId,
            chapterId: chapterId,
            segmentCount: chapterSegments.length,
            selectedSegmentId: selected?.chapterId == chapterId
                ? selected?.id
                : null,
            beforeChange: beforeChange,
          ),
        NovelCharacterList(
          projectId: projectId,
          roles: roles,
          assets: assets,
          beforeChange: beforeChange,
          chapterId: chapterId,
        ),
        const Divider(height: 32),
        if (selected != null) ...[
          NovelStructureTools(
            segment: selected,
            segments: segments,
            beforeChange: beforeChange,
            onSelect: onSelect,
          ),
          NovelCharacterTools(
            segment: selected,
            segments: segments,
            roles: roles,
            assets: assets,
            beforeChange: beforeChange,
          ),
        ],
        if (selected == null)
          Text(l.rolePickSentence)
        else
          NovelAnnotationEditor(
            key: ValueKey(
              '${selected.id}:${roles.annotations[selected.id]?.changeId}',
            ),
            segment: selected,
            roles: roles,
            segments: segments,
            assets: assets,
            beforeChange: beforeChange,
            onPreview: () => onPreview(selected),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.undo_rounded),
          label: Text(l.roleUndo),
          onPressed: () async {
            beforeChange();
            try {
              await ref.read(annotationRepositoryProvider).undo(projectId);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
        ),
        const Divider(height: 32),
        Text(
          '${l.rolePendingList} · ${pending.length}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChip(
            label: Text(l.rolePollOnlyUncertain),
            selected: _onlyUncertain,
            onSelected: (value) => setState(() {
              _onlyUncertain = value;
              _shown = 12;
            }),
          ),
        ),
        if (pending.isEmpty)
          Text(_onlyUncertain ? l.roleNoUncertain : l.roleNoPending),
        for (final segment in pending.take(_shown))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline_rounded, size: 18),
            title: Text(
              segment.segmentText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(segment),
          ),
        if (pending.length > _shown)
          TextButton(
            onPressed: () => setState(() => _shown += 12),
            child: Text(l.roleShowMorePending),
          ),
      ],
    );
  }
}
