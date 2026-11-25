import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

import 'role_labels.dart';

class NovelRoleReviewReader extends StatelessWidget {
  const NovelRoleReviewReader({
    super.key,
    required this.project,
    required this.roles,
    required this.segments,
    required this.cacheStates,
    required this.onSelect,
    required this.onPreview,
    this.selectedId,
    this.playingIndex,
  });
  final db.NovelProject project;
  final NovelRoleSnapshot roles;
  final List<db.NovelSegment> segments;
  final Map<String, String> cacheStates;
  final String? selectedId;
  final int? playingIndex;
  final ValueChanged<db.NovelSegment> onSelect;
  final ValueChanged<db.NovelSegment> onPreview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final characters = {for (final c in roles.characters) c.id: c};
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        final stored = roles.annotations[segment.id];
        final annotation =
            stored?.textRevision == novelTextRevision(segment.segmentText)
            ? stored
            : null;
        final character = characters[annotation?.characterId];
        final kind =
            annotation?.kind ??
            (segment.segmentType == 'dialogue'
                ? NovelSegmentKind.dialogue
                : NovelSegmentKind.narrator);
        final status = annotation?.reviewState ?? NovelReviewState.pending;
        final cache = cacheStates[segment.id];
        return Card(
          color: segment.globalIndex == playingIndex
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: segment.id == selectedId
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            onTap: () => onSelect(segment),
            onDoubleTap: () => onPreview(segment),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.circle_rounded,
                        size: 8,
                        color: Color(character?.color ?? 0xFF9E9E9E),
                      ),
                      Text(
                        character?.name ??
                            (kind == NovelSegmentKind.narrator
                                ? l.roleNarrator
                                : l.roleNoCharacter),
                      ),
                      Text(
                        roleKindLabel(l, kind),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (annotation?.locked ?? false)
                        const Icon(Icons.lock_outline_rounded, size: 14),
                      Text(
                        roleReviewLabel(l, status),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Tooltip(
                        message: cache == 'current'
                            ? l.roleCached
                            : cache == 'stale'
                            ? l.roleStaleCache
                            : l.roleNoCache,
                        child: Icon(
                          cache == 'current'
                              ? Icons.cloud_done_rounded
                              : cache == 'stale'
                              ? Icons.refresh_rounded
                              : Icons.cloud_off_rounded,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    segment.segmentText,
                    style: TextStyle(
                      fontSize: project.fontSize,
                      height: project.lineHeight,
                    ),
                  ),
                  if (annotation?.reason.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        annotation!.reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
