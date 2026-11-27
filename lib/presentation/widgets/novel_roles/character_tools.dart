import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

import 'role_labels.dart';

class NovelCharacterTools extends ConsumerWidget {
  const NovelCharacterTools({
    super.key,
    required this.segment,
    required this.segments,
    required this.roles,
    required this.assets,
    required this.beforeChange,
  });
  final db.NovelSegment segment;
  final List<db.NovelSegment> segments;
  final NovelRoleSnapshot roles;
  final List<db.VoiceAsset> assets;
  final VoidCallback beforeChange;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = roles.annotations[segment.id]?.characterId;
    final character = roles.characters.where((c) => c.id == id).firstOrNull;
    if (character == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.tune_rounded),
          label: Text(l.roleStyleMatrix),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _StyleDialog(
              character: character,
              chapterId: segment.chapterId,
              roles: roles,
              assets: assets,
              beforeChange: beforeChange,
            ),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.person_add_alt_rounded),
          label: Text(l.roleSplitCharacter),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _CharacterSplitDialog(
              character: character,
              segments: segments
                  .where(
                    (s) =>
                        s.chapterId == segment.chapterId &&
                        roles.annotations[s.id]?.characterId == id,
                  )
                  .toList(),
              initialId: segment.id,
              beforeChange: beforeChange,
            ),
          ),
        ),
      ],
    );
  }
}

class _StyleDialog extends ConsumerStatefulWidget {
  const _StyleDialog({
    required this.character,
    required this.chapterId,
    required this.roles,
    required this.assets,
    required this.beforeChange,
  });
  final StoryCharacter character;
  final String chapterId;
  final NovelRoleSnapshot roles;
  final List<db.VoiceAsset> assets;
  final VoidCallback beforeChange;
  @override
  ConsumerState<_StyleDialog> createState() => _StyleDialogState();
}

class _StyleDialogState extends ConsumerState<_StyleDialog> {
  NovelSegmentKind _kind = NovelSegmentKind.dialogue;
  bool _chapter = false;
  String? _voice;
  bool _busy = false;
  final _instruction = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final binding = widget.roles.bindings
        .where(
          (b) =>
              b.characterId == widget.character.id &&
              b.kind == _kind &&
              b.chapterId == (_chapter ? widget.chapterId : ''),
        )
        .firstOrNull;
    _voice = widget.assets.any((v) => v.id == binding?.voiceAssetId)
        ? binding?.voiceAssetId
        : null;
    _instruction.text = binding?.instruction ?? '';
  }

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${widget.character.name} · ${l.roleStyleMatrix}'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<NovelSegmentKind>(
                initialValue: _kind,
                items: [
                  for (final k in NovelSegmentKind.values)
                    DropdownMenuItem(
                      value: k,
                      child: Text(roleKindLabel(l, k)),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _kind = v!;
                        _load();
                      }),
              ),
              CheckboxListTile(
                value: _chapter,
                title: Text(l.roleChapterOverride),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _chapter = v ?? false;
                        _load();
                      }),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('$_kind:$_chapter:$_voice'),
                initialValue: _voice ?? '',
                isExpanded: true,
                decoration: InputDecoration(labelText: l.roleSentenceVoice),
                items: [
                  DropdownMenuItem(value: '', child: Text(l.roleDefaultVoice)),
                  for (final v in widget.assets)
                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                onChanged: _busy ? null : (v) => _voice = v == '' ? null : v,
              ),
              TextField(
                controller: _instruction,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l.roleInstruction),
              ),
              Text(l.roleStyleHelp),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.uiSave)),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    widget.beforeChange();
    try {
      await ref
          .read(rolePreferencesProvider)
          .setStyle(
            projectId: widget.character.projectId,
            characterId: widget.character.id,
            kind: _kind,
            chapterId: _chapter ? widget.chapterId : '',
            voiceAssetId: _voice,
            instruction: _instruction.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _CharacterSplitDialog extends ConsumerStatefulWidget {
  const _CharacterSplitDialog({
    required this.character,
    required this.segments,
    required this.initialId,
    required this.beforeChange,
  });
  final StoryCharacter character;
  final List<db.NovelSegment> segments;
  final String initialId;
  final VoidCallback beforeChange;
  @override
  ConsumerState<_CharacterSplitDialog> createState() =>
      _CharacterSplitDialogState();
}

class _CharacterSplitDialogState extends ConsumerState<_CharacterSplitDialog> {
  final _name = TextEditingController();
  late final _selected = {widget.initialId};
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.roleSplitCharacter),
      content: SizedBox(
        width: 600,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: InputDecoration(labelText: l.roleName),
            ),
            Text(l.roleSplitCharacterHelp),
            Expanded(
              child: ListView(
                children: [
                  for (final s in widget.segments)
                    CheckboxListTile(
                      value: _selected.contains(s.id),
                      title: Text(s.segmentText),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: _busy || _selected.isEmpty ? null : _save,
          child: Text(l.roleSplitCharacter),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    widget.beforeChange();
    try {
      await ref
          .read(characterSplitServiceProvider)
          .split(
            projectId: widget.character.projectId,
            sourceId: widget.character.id,
            name: _name.text,
            expected: widget.segments
                .where((s) => _selected.contains(s.id))
                .toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
