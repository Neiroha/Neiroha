import 'character_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

class NovelCharacterList extends ConsumerStatefulWidget {
  const NovelCharacterList({
    super.key,
    required this.projectId,
    required this.roles,
    required this.assets,
    required this.beforeChange,
    this.chapterId,
  });
  final String projectId;
  final String? chapterId;
  final NovelRoleSnapshot roles;
  final List<db.VoiceAsset> assets;
  final VoidCallback beforeChange;
  @override
  ConsumerState<NovelCharacterList> createState() => _NovelCharacterListState();
}

class _NovelCharacterListState extends ConsumerState<NovelCharacterList> {
  bool _chapterOnly = false;

  Future<void> _run(Future<void> Function() action) async {
    widget.beforeChange();
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chapter = _chapterOnly ? widget.chapterId ?? '' : '';
    final counts = <String, int>{};
    for (final a in widget.roles.annotations.values) {
      if (a.characterId != null) {
        counts.update(a.characterId!, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.roleCharacters,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l.roleAddCharacter,
              icon: const Icon(Icons.person_add_alt),
              onPressed: () => _edit(),
            ),
          ],
        ),
        if (widget.chapterId != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.roleChapterOverride),
            value: _chapterOnly,
            onChanged: (v) => setState(() => _chapterOnly = v ?? false),
          ),
        for (final character in widget.roles.characters)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, color: Color(character.color), size: 9),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${character.name} · ${counts[character.id] ?? 0}',
                      ),
                    ),
                    IconButton(
                      tooltip: l.roleRename,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => _edit(character),
                    ),
                    if (widget.roles.characters.length > 1)
                      PopupMenuButton<String>(
                        tooltip: l.roleMerge,
                        icon: const Icon(Icons.merge_type, size: 18),
                        itemBuilder: (_) => [
                          for (final target in widget.roles.characters)
                            if (target.id != character.id)
                              PopupMenuItem(
                                value: target.id,
                                child: Text(
                                  '${l.roleMergeInto} ${target.name}',
                                ),
                              ),
                        ],
                        onSelected: (target) => _run(
                          () => ref
                              .read(characterRepositoryProvider)
                              .merge(widget.projectId, character.id, target),
                        ),
                      ),
                  ],
                ),
                if (character.aliases.isNotEmpty)
                  Text(
                    character.aliases.join(' / '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Builder(
                  builder: (_) {
                    final binding = widget.roles.bindings
                        .where(
                          (b) =>
                              b.characterId == character.id &&
                              b.chapterId == chapter,
                        )
                        .firstOrNull;
                    final voice =
                        widget.assets.any((a) => a.id == binding?.voiceAssetId)
                        ? binding?.voiceAssetId
                        : null;
                    return DropdownButtonFormField<String>(
                      key: ValueKey('${character.id}:$chapter:$voice'),
                      initialValue: voice ?? '',
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.roleVoice),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(l.roleDefaultVoice),
                        ),
                        for (final v in widget.assets)
                          DropdownMenuItem(value: v.id, child: Text(v.name)),
                      ],
                      onChanged: (v) => _run(
                        () => ref
                            .read(characterRepositoryProvider)
                            .bindVoice(
                              projectId: widget.projectId,
                              characterId: character.id,
                              voiceAssetId: v == '' ? null : v,
                              chapterId: chapter,
                            ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _edit([StoryCharacter? character]) async {
    final draft = await showDialog<CharacterDraft>(
      context: context,
      builder: (_) => CharacterEditorDialog(character: character),
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      await ref
          .read(characterRepositoryProvider)
          .saveCharacter(
            projectId: widget.projectId,
            id: character?.id,
            name: draft.name,
            aliases: draft.aliases,
            description: draft.description,
            identityKind: draft.identityKind,
            color: character?.color,
          );
    });
  }
}
