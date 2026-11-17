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

class NovelRoleReviewPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final pending = segments.where((s) {
      if (s.chapterId != chapterId) return false;
      final a = roles.annotations[s.id];
      return a?.textRevision != novelTextRevision(s.segmentText) ||
          (a?.reviewState != NovelReviewState.confirmed);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (chapterId != null)
          NovelRoleAnalysisControls(
            key: ValueKey('$projectId:$chapterId'),
            projectId: projectId,
            chapterId: chapterId!,
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
            segment: selected!,
            segments: segments,
            beforeChange: beforeChange,
            onSelect: onSelect,
          ),
          NovelCharacterTools(
            segment: selected!,
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
              '${selected!.id}:${roles.annotations[selected!.id]?.changeId}',
            ),
            segment: selected!,
            roles: roles,
            segments: segments,
            assets: assets,
            beforeChange: beforeChange,
            onPreview: () => onPreview(selected!),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.undo),
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
        if (pending.isEmpty) Text(l.roleNoPending),
        for (final segment in pending)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline, size: 18),
            title: Text(
              segment.segmentText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onSelect(segment),
          ),
      ],
    );
  }
}
