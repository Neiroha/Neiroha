import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

import 'role_labels.dart';

class NovelAnnotationEditor extends ConsumerStatefulWidget {
  const NovelAnnotationEditor({
    super.key,
    required this.segment,
    required this.roles,
    required this.segments,
    required this.assets,
    required this.beforeChange,
    required this.onPreview,
  });
  final db.NovelSegment segment;
  final NovelRoleSnapshot roles;
  final List<db.NovelSegment> segments;
  final List<db.VoiceAsset> assets;
  final VoidCallback beforeChange;
  final VoidCallback onPreview;
  @override
  ConsumerState<NovelAnnotationEditor> createState() =>
      _NovelAnnotationEditorState();
}

class _NovelAnnotationEditorState extends ConsumerState<NovelAnnotationEditor> {
  String? _character;
  String? _voice;
  late NovelSegmentKind _kind;
  late TextEditingController _instruction;
  bool _locked = true;
  bool _chapter = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final stored = widget.roles.annotations[widget.segment.id];
    final a =
        stored?.textRevision == novelTextRevision(widget.segment.segmentText)
        ? stored
        : null;
    _character = widget.roles.characters.any((c) => c.id == a?.characterId)
        ? a?.characterId
        : null;
    _voice = widget.assets.any((v) => v.id == a?.voiceAssetId)
        ? a?.voiceAssetId
        : null;
    _kind =
        a?.kind ??
        (widget.segment.segmentType == 'dialogue'
            ? NovelSegmentKind.dialogue
            : NovelSegmentKind.narrator);
    _locked = a?.locked ?? true;
    _instruction = TextEditingController(text: a?.instruction ?? '');
  }

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final previous = widget.roles.annotations[widget.segment.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.roleSelected, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          widget.segment.segmentText,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _character ?? '',
          isExpanded: true,
          decoration: InputDecoration(labelText: l.roleCharacters),
          items: [
            DropdownMenuItem(value: '', child: Text(l.roleNoCharacter)),
            for (final c in widget.roles.characters)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() => _character = v == '' ? null : v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<NovelSegmentKind>(
          initialValue: _kind,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.roleCategory),
          items: [
            for (final kind in NovelSegmentKind.values)
              DropdownMenuItem(
                value: kind,
                child: Text(roleKindLabel(l, kind)),
              ),
          ],
          onChanged: _busy ? null : (v) => setState(() => _kind = v!),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _voice ?? '',
          isExpanded: true,
          decoration: InputDecoration(labelText: l.roleSentenceVoice),
          items: [
            DropdownMenuItem(value: '', child: Text(l.roleDefaultVoice)),
            for (final v in widget.assets)
              DropdownMenuItem(value: v.id, child: Text(v.name)),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() => _voice = v == '' ? null : v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instruction,
          decoration: InputDecoration(labelText: l.roleInstruction),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<bool>(
          initialValue: false,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.roleScope),
          items: [
            DropdownMenuItem(value: false, child: Text(l.roleOnlySentence)),
            if (previous?.characterId != null)
              DropdownMenuItem(value: true, child: Text(l.roleChapterUnlocked)),
          ],
          onChanged: _busy
              ? null
              : (v) => setState(() => _chapter = v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.roleLock),
          value: _locked,
          onChanged: _busy ? null : (v) => setState(() => _locked = v ?? true),
        ),
        FilledButton(
          onPressed: _busy ? null : _apply,
          child: Text(l.roleApply),
        ),
        TextButton.icon(
          onPressed: _busy ? null : widget.onPreview,
          icon: const Icon(Icons.play_arrow),
          label: Text(l.rolePreview),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    widget.beforeChange();
    try {
      final oldCharacter =
          widget.roles.annotations[widget.segment.id]?.characterId;
      final targets = !_chapter
          ? [widget.segment]
          : widget.segments.where((s) {
              final a = widget.roles.annotations[s.id];
              return s.chapterId == widget.segment.chapterId &&
                  a?.characterId == oldCharacter &&
                  !(a?.locked ?? false);
            }).toList();
      await ref
          .read(annotationRepositoryProvider)
          .apply(widget.segment.projectId, [
            for (final s in targets)
              SegmentAnnotation(
                segmentId: s.id,
                projectId: s.projectId,
                textRevision: novelTextRevision(s.segmentText),
                characterId: _character,
                kind: _kind,
                locked: _locked,
                voiceAssetId: _voice,
                instruction: _instruction.text.trim().isEmpty
                    ? null
                    : _instruction.text.trim(),
                reason: l.roleManualReason,
              ),
          ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
