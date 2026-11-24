part of '../../screens/novel_reader_screen.dart';

// The chapter edit pane, its editable rows and the chapter dialog.

class _ChapterEditPane extends StatelessWidget {
  final db.NovelProject project;
  final db.NovelChapter? chapter;
  final List<db.NovelSegment> segments;
  final int? currentGlobalIndex;
  final ValueChanged<db.NovelSegment> onPickSegment;
  final void Function(db.NovelSegment segment, String text) onSaveSegment;
  final ValueChanged<db.NovelSegment> onDeleteSegment;

  const _ChapterEditPane({
    required this.project,
    required this.chapter,
    required this.segments,
    required this.currentGlobalIndex,
    required this.onPickSegment,
    required this.onSaveSegment,
    required this.onDeleteSegment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F14),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppTheme.accentColor,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    chapter?.title ?? 'No chapter selected',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${segments.length} segments',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: chapter == null
                ? Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).uiImportOrAddAChapterToEditNovelText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      return _EditableSegmentRow(
                        key: ValueKey(segment.id),
                        segment: segment,
                        index: index,
                        active: segment.globalIndex == currentGlobalIndex,
                        fontSize: project.fontSize,
                        lineHeight: project.lineHeight,
                        onPick: () => onPickSegment(segment),
                        onSave: (text) => onSaveSegment(segment, text),
                        onDelete: () => onDeleteSegment(segment),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditableSegmentRow extends StatefulWidget {
  final db.NovelSegment segment;
  final int index;
  final bool active;
  final double fontSize;
  final double lineHeight;
  final VoidCallback onPick;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  const _EditableSegmentRow({
    super.key,
    required this.segment,
    required this.index,
    required this.active,
    required this.fontSize,
    required this.lineHeight,
    required this.onPick,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditableSegmentRow> createState() => _EditableSegmentRowState();
}

class _EditableSegmentRowState extends State<_EditableSegmentRow> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.segment.segmentText);
  }

  @override
  void didUpdateWidget(covariant _EditableSegmentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segment.id != widget.segment.id ||
        oldWidget.segment.segmentText != widget.segment.segmentText) {
      _controller.text = widget.segment.segmentText;
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.active
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.surfaceDim,
        border: Border.all(
          color: widget.active
              ? AppTheme.accentColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: InkWell(
                onTap: widget.onPick,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    children: [
                      Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: widget.active
                              ? AppTheme.accentColor
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SizedBox(height: 6),
                      Icon(
                        widget.segment.segmentType == 'dialogue'
                            ? Icons.record_voice_over_rounded
                            : Icons.notes_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 2,
                maxLines: null,
                style: TextStyle(
                  fontSize: widget.fontSize.clamp(16, 22),
                  height: widget.lineHeight.clamp(1.35, 2.0),
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  final dirty = value.trim() != widget.segment.segmentText;
                  if (dirty != _dirty) setState(() => _dirty = dirty);
                },
              ),
            ),
            SizedBox(width: 6),
            Column(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context).uiSaveSegment,
                  onPressed: _dirty
                      ? () => widget.onSave(_controller.text)
                      : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).uiDeleteSegment,
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterEditDialog extends StatefulWidget {
  final String initialTitle;
  final String initialText;
  final bool isNew;

  const _ChapterEditDialog({
    required this.initialTitle,
    required this.initialText,
    required this.isNew,
  });

  @override
  State<_ChapterEditDialog> createState() => _ChapterEditDialogState();
}

class _ChapterEditDialogState extends State<_ChapterEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add Chapter' : 'Edit Chapter'),
      content: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              autofocus: widget.isNew,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiChapterTitle,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _textController,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiChapterText,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty ? null : _submit,
          child: Text(AppLocalizations.of(context).uiSave),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _ChapterEditResult(title: title, rawText: _textController.text.trim()),
    );
  }
}

class _ChapterEditResult {
  final String title;
  final String rawText;

  const _ChapterEditResult({required this.title, required this.rawText});
}
