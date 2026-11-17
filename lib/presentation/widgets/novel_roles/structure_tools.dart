import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/novel_role_providers.dart';

class NovelStructureTools extends ConsumerWidget {
  const NovelStructureTools({
    super.key,
    required this.segment,
    required this.segments,
    required this.beforeChange,
    required this.onSelect,
  });
  final db.NovelSegment segment;
  final List<db.NovelSegment> segments;
  final VoidCallback beforeChange;
  final ValueChanged<db.NovelSegment> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    Future<void> run(Future<List<db.NovelSegment>> Function() action) async {
      beforeChange();
      try {
        final result = await action();
        if (context.mounted && result.isNotEmpty) onSelect(result.first);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
      }
    }

    final editor = ref.read(novelStructureEditorProvider);
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.call_split),
          label: Text(l.roleSplitText),
          onPressed: () async {
            final selection = await showDialog<TextSelection>(
              context: context,
              builder: (_) => _SplitRangeDialog(text: segment.segmentText),
            );
            if (selection != null) {
              await run(
                () => editor.split(segment, selection.start, selection.end),
              );
            }
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.call_merge),
          label: Text(l.roleMergeText),
          onPressed: () async {
            final chapter =
                segments
                    .where(
                      (s) =>
                          s.chapterId == segment.chapterId &&
                          s.orderIndex >= segment.orderIndex,
                    )
                    .toList()
                  ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
            if (chapter.length < 2) return;
            final result = await showDialog<({int end, bool newline})>(
              context: context,
              builder: (_) => _MergeRangeDialog(segments: chapter),
            );
            if (result != null) {
              await run(
                () => editor.merge(
                  chapter.take(result.end + 1).toList(),
                  separator: result.newline ? '\n' : '',
                ),
              );
            }
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.undo),
          label: Text(l.roleUndoStructure),
          onPressed: () => run(() async {
            await editor.undo(segment.projectId);
            return [];
          }),
        ),
      ],
    );
  }
}

class _SplitRangeDialog extends StatefulWidget {
  const _SplitRangeDialog({required this.text});
  final String text;
  @override
  State<_SplitRangeDialog> createState() => _SplitRangeDialogState();
}

class _SplitRangeDialogState extends State<_SplitRangeDialog> {
  late final _text = TextEditingController(text: widget.text);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.roleSplitText),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.roleSplitTextHelp),
            Flexible(
              child: TextField(
                controller: _text,
                readOnly: true,
                maxLines: 12,
                enableInteractiveSelection: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_text.selection.isValid) {
              Navigator.pop(context, _text.selection);
            }
          },
          child: Text(l.roleSplitText),
        ),
      ],
    );
  }
}

class _MergeRangeDialog extends StatefulWidget {
  const _MergeRangeDialog({required this.segments});
  final List<db.NovelSegment> segments;
  @override
  State<_MergeRangeDialog> createState() => _MergeRangeDialogState();
}

class _MergeRangeDialogState extends State<_MergeRangeDialog> {
  int _end = 1;
  bool _newline = true;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.roleMergeText),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.roleMergeTextHelp),
            DropdownButtonFormField<int>(
              initialValue: _end,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.roleMergeUntil),
              items: [
                for (var i = 1; i < widget.segments.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      widget.segments[i].segmentText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _end = v ?? 1),
            ),
            CheckboxListTile(
              value: _newline,
              title: Text(l.roleMergeNewline),
              onChanged: (v) => setState(() => _newline = v ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (end: _end, newline: _newline)),
          child: Text(l.roleMergeText),
        ),
      ],
    );
  }
}
