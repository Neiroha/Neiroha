import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'role_labels.dart';

class NovelToolReviewDialog extends StatefulWidget {
  const NovelToolReviewDialog({
    super.key,
    required this.session,
    required this.roles,
    required this.segments,
  });
  final RoleReviewSession session;
  final NovelRoleSnapshot roles;
  final List<db.NovelSegment> segments;
  @override
  State<NovelToolReviewDialog> createState() => _NovelToolReviewDialogState();
}

class _NovelToolReviewDialogState extends State<NovelToolReviewDialog> {
  final _selected = <String>{};
  String _name(Object? id) {
    if (id == null) return AppLocalizations.of(context).roleNarrator;
    final added = widget.session.proposals
        .where((p) => p.action == 'propose_character' && 'new:${p.key}' == id)
        .firstOrNull;
    return added?.data['name'] as String? ??
        widget.roles.characters.where((c) => c.id == id).firstOrNull?.name ??
        '$id';
  }

  String _text(Object? id) =>
      widget.segments.where((s) => s.id == id).firstOrNull?.segmentText ??
      '$id';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final missingDependency = widget.session.proposals.any((p) {
      final target = p.data['characterRef'];
      return _selected.contains(p.key) &&
          target is String &&
          target.startsWith('new:') &&
          !_selected.contains(target.substring(4));
    });
    return AlertDialog(
      title: Text(l.roleToolReviewProposals),
      content: SizedBox(
        width: 650,
        height: 480,
        child: ListView(
          children: [
            Text(l.roleToolApplyHint),
            if (widget.session.proposals.isEmpty) Text(l.roleToolEmpty),
            for (final p in widget.session.proposals)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selected.contains(p.key),
                      title: Text(_title(l, p)),
                      subtitle: Text(p.reason),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selected.add(p.key);
                        } else {
                          _selected.remove(p.key);
                        }
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.action == 'propose_character') ...[
                            Text((p.data['aliases'] as List).join(' / ')),
                            Text(p.data['description'] as String),
                          ],
                          if (p.action == 'propose_patch') ...[
                            Text(_text(p.data['segmentId'])),
                            Text(
                              '${_name(widget.roles.annotations[p.data['segmentId']]?.characterId)} → ${_name(p.data['characterRef'])}',
                            ),
                          ],
                          if (p.action == 'propose_merge') ...[
                            Text(l.roleToolAffected),
                            for (final id in p.data['affectedIds'] as List)
                              Text('• ${_text(id)}'),
                          ],
                          Text(
                            l.roleToolEvidence,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          for (final evidence in p.evidence)
                            Text('「${evidence['quote']}」'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (missingDependency) Text(l.roleToolDependency),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty || missingDependency
              ? null
              : () => Navigator.pop(context, _selected),
          child: Text(l.roleApply),
        ),
      ],
    );
  }

  String _title(AppLocalizations l, RoleReviewProposal p) => switch (p.action) {
    'propose_character' => '${l.roleToolAdd} · ${p.data['name']}',
    'propose_merge' =>
      '${l.roleToolMerge} · ${_name(p.data['fromId'])} → ${_name(p.data['intoId'])}',
    _ =>
      '${l.roleToolPatch} · ${_name(p.data['characterRef'])} · ${roleKindLabel(l, NovelSegmentKind.values.byName(p.data['kind'] as String))}',
  };
}
