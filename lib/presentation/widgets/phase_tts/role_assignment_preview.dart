import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import '../novel_roles/role_labels.dart';
import '../novel_roles/scene_summary.dart';

String _textRoleName(
  AppLocalizations l,
  TextRoleUnit unit,
  Map<String, StoryCharacter> cast,
) =>
    cast[unit.characterId]?.name ??
    switch (unit.kind) {
      NovelSegmentKind.narrator => l.roleNarrator,
      NovelSegmentKind.system => l.roleSystem,
      _ => l.phaseRoleUnknown,
    };

class RoleAssignmentPreview extends StatefulWidget {
  const RoleAssignmentPreview({
    super.key,
    required this.plan,
    required this.voices,
    required this.voiceByRole,
    required this.setVoice,
    required this.editUnit,
  });
  final TextRolePlan plan;
  final List<db.VoiceAsset> voices;
  final Map<String, String?> voiceByRole;
  final void Function(String, String?) setVoice;
  final ValueChanged<int> editUnit;

  @override
  State<RoleAssignmentPreview> createState() => _RoleAssignmentPreviewState();
}

class _RoleAssignmentPreviewState extends State<RoleAssignmentPreview> {
  bool _voiceTab = false, _onlyUncertain = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), theme = Theme.of(context);
    final plan = widget.plan;
    final cast = {for (final c in plan.characters) c.id: c};
    final unresolved = plan.units.where((u) => u.needsReview).length;
    final roleUnits = <String, List<TextRoleUnit>>{};
    for (final unit in plan.units) {
      roleUnits.putIfAbsent(unit.voiceKey, () => []).add(unit);
    }
    final missing = roleUnits.keys
        .where((key) => widget.voiceByRole[key] == null)
        .length;
    final filtered = plan.units.indexed.where((entry) {
      final unit = entry.$2;
      return (!_onlyUncertain || unit.needsReview) &&
          (_query.isEmpty ||
              unit.text.toLowerCase().contains(_query) ||
              _textRoleName(l, unit, cast).toLowerCase().contains(_query));
    }).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.phaseRoleReviewSummary(
                  plan.units.length,
                  unresolved,
                  missing,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.phaseRoleSegments),
                    selected: !_voiceTab,
                    onSelected: (selected) {
                      if (selected) setState(() => _voiceTab = false);
                    },
                  ),
                  ChoiceChip(
                    label: Text(l.phaseRoleVoices),
                    selected: _voiceTab,
                    onSelected: (selected) {
                      if (selected) setState(() => _voiceTab = true);
                    },
                  ),
                  if (!_voiceTab)
                    FilterChip(
                      label: Text(l.phaseRoleNeedsReview),
                      selected: _onlyUncertain,
                      onSelected: (v) => setState(() => _onlyUncertain = v),
                    ),
                ],
              ),
              if (!_voiceTab)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 10),
                  child: TextFormField(
                    initialValue: _query,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: l.phaseRoleSearch,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_voiceTab)
          SliverList.list(
            children: [
              Text(l.phaseRoleVoiceHelp, style: theme.textTheme.bodySmall),
              for (final entry in roleUnits.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('voice-${entry.key}'),
                    initialValue: widget.voiceByRole[entry.key] ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText:
                          '${_textRoleName(l, entry.value.first, cast)} · ${entry.value.length} ${l.roleAnalysisSentences}',
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l.phaseRoleNoVoice),
                      ),
                      for (final v in widget.voices)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text(v.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) =>
                        widget.setVoice(entry.key, v == '' ? null : v),
                  ),
                ),
            ],
          )
        else ...[
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l.phaseRoleNoMatches),
              ),
            )
          else if (plan.scene case final scene?
              when !_onlyUncertain &&
                  _query.isEmpty &&
                  (scene.evidence.isNotEmpty || scene.firstPersonId != null))
            SliverToBoxAdapter(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.roleSceneTitle),
                children: [
                  NovelRoleSceneSummary(
                    scene: scene,
                    roles: NovelRoleSnapshot(characters: plan.characters),
                    showHelp: false,
                  ),
                ],
              ),
            ),
          SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final (position, unit) = filtered[index];
              return _RolePreviewRow(
                key: ValueKey(unit.start),
                unit: unit,
                title: '${position + 1} · ${_textRoleName(l, unit, cast)}',
                edit: () => widget.editUnit(position),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _RolePreviewRow extends StatelessWidget {
  const _RolePreviewRow({
    super.key,
    required this.unit,
    required this.title,
    required this.edit,
  });
  final TextRoleUnit unit;
  final String title;
  final VoidCallback edit;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), theme = Theme.of(context);
    final status = unit.needsReview
        ? l.phaseRoleNeedsReview
        : unit.manuallyEdited
        ? l.phaseRoleEdited
        : l.roleInferred;
    return Card(
      color: unit.needsReview ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: edit,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${roleKindLabel(l, unit.kind)} · $status',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              unit.text.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (unit.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  unit.reason,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: l.phaseRoleEditSegment,
          icon: const Icon(Icons.edit_outlined),
          onPressed: edit,
        ),
      ),
    );
  }
}
