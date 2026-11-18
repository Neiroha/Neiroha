import 'package:flutter/material.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import '../novel_roles/role_labels.dart';

class RoleAssignmentEdit {
  const RoleAssignmentEdit(this.kind, this.characterId, {this.newName});
  final NovelSegmentKind kind;
  final String? characterId, newName;
}

class RoleAssignmentEditor extends StatefulWidget {
  const RoleAssignmentEditor({
    super.key,
    required this.original,
    required this.unit,
    required this.characters,
    this.before,
    this.after,
  });
  final TextRoleUnit original, unit;
  final List<StoryCharacter> characters;
  final String? before, after;
  @override
  State<RoleAssignmentEditor> createState() => _RoleAssignmentEditorState();
}

class _RoleAssignmentEditorState extends State<RoleAssignmentEditor> {
  static const _new = '@new';
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late var _kind = widget.unit.kind;
  late var _character = widget.unit.characterId ?? '';
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l.phaseRoleEditSegment),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                widget.unit.text.trim(),
                style: theme.textTheme.bodyLarge,
              ),
              if (widget.original.reason.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${l.phaseRoleModelEvidence}\n${widget.original.reason}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (widget.before != null || widget.after != null)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l.phaseRoleContext),
                  children: [
                    if (widget.before case final text?)
                      ListTile(
                        title: Text(l.phaseRolePrevious),
                        subtitle: Text(text.trim()),
                      ),
                    if (widget.after case final text?)
                      ListTile(
                        title: Text(l.phaseRoleFollowing),
                        subtitle: Text(text.trim()),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<NovelSegmentKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.phaseRoleCategory),
                items: [
                  for (final kind in NovelSegmentKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(roleKindLabel(l, kind)),
                    ),
                ],
                onChanged: (v) => setState(() => _kind = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _character,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.phaseRoleSpeaker),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l.phaseRoleNoCharacter),
                  ),
                  for (final c in widget.characters)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  DropdownMenuItem(
                    value: _new,
                    child: Text(l.phaseRoleAddCharacter),
                  ),
                ],
                onChanged: (v) => setState(() => _character = v!),
              ),
              if (_character == _new) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 80,
                  decoration: InputDecoration(
                    labelText: l.phaseRoleCharacterName,
                  ),
                  validator: (v) {
                    final name = (v ?? '').trim();
                    if (name.isEmpty ||
                        widget.characters.any(
                          (c) => c.name == name || c.aliases.contains(name),
                        )) {
                      return l.phaseRoleNameRequired;
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.unit.manuallyEdited)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              RoleAssignmentEdit(
                widget.original.kind,
                widget.original.characterId,
              ),
            ),
            child: Text(l.phaseRoleRestoreSuggestion),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                RoleAssignmentEdit(
                  _kind,
                  _character.isEmpty || _character == _new ? null : _character,
                  newName: _character == _new ? _name.text.trim() : null,
                ),
              );
            }
          },
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
