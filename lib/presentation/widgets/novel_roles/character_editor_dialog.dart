import 'package:flutter/material.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class CharacterDraft {
  const CharacterDraft(
    this.name,
    this.aliases,
    this.description,
    this.identityKind,
  );
  final String name;
  final List<String> aliases;
  final String description;
  final CharacterIdentityKind identityKind;
}

class CharacterEditorDialog extends StatefulWidget {
  const CharacterEditorDialog({super.key, this.character});
  final StoryCharacter? character;
  @override
  State<CharacterEditorDialog> createState() => _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends State<CharacterEditorDialog> {
  late final _name = TextEditingController(text: widget.character?.name ?? '');
  late final _aliases = TextEditingController(
    text: widget.character?.aliases.join(', ') ?? '',
  );
  late final _description = TextEditingController(
    text: widget.character?.description ?? '',
  );
  late var _kind =
      widget.character?.identityKind ?? CharacterIdentityKind.named;
  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.character == null ? l.roleAddCharacter : l.roleRename),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.roleName),
              ),
              DropdownButtonFormField<CharacterIdentityKind>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: l.roleIdentityKind),
                items: [
                  DropdownMenuItem(
                    value: CharacterIdentityKind.named,
                    child: Text(l.roleIdentityNamed),
                  ),
                  DropdownMenuItem(
                    value: CharacterIdentityKind.anonymous,
                    child: Text(l.roleIdentityAnonymous),
                  ),
                  DropdownMenuItem(
                    value: CharacterIdentityKind.group,
                    child: Text(l.roleIdentityGroup),
                  ),
                ],
                onChanged: (v) => setState(() => _kind = v!),
              ),
              TextField(
                controller: _aliases,
                decoration: InputDecoration(labelText: l.roleAliases),
              ),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: l.roleDescription),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              CharacterDraft(
                _name.text,
                _aliases.text.split(RegExp('[,，]')),
                _description.text,
                _kind,
              ),
            );
          },
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
