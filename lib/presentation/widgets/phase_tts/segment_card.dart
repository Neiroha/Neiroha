part of 'segment_voice_panel.dart';

/// A sentence's status, text, speaker, style, voice and actions.
class _SegmentCard extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final bool isLast;
  final List<db.VoiceAsset> assets;
  final SegmentVoiceSettings? settings;
  final bool isGenerating;
  final bool isPlaying;
  final bool focused;
  final bool selecting;
  final bool selected;

  /// Position for the drag handle; null when reordering is unavailable
  /// (filtered list, multi-select).
  final int? dragIndex;
  final VoidCallback onTap;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onSettings;
  final VoidCallback onEditText;
  final VoidCallback onSplit;
  final VoidCallback onMergeNext;
  final VoidCallback onInsertBelow;
  final VoidCallback onTogglePlay;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const _SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.isLast,
    required this.assets,
    required this.settings,
    required this.isGenerating,
    required this.isPlaying,
    required this.focused,
    required this.selecting,
    required this.selected,
    required this.dragIndex,
    required this.onTap,
    required this.onVoiceChanged,
    required this.onSettings,
    required this.onEditText,
    required this.onSplit,
    required this.onMergeNext,
    required this.onInsertBelow,
    required this.onTogglePlay,
    required this.onGenerate,
    required this.onDelete,
  });

  _SegmentStatus get _status {
    if (isGenerating) return _SegmentStatus.generating;
    if (segment.error != null) return _SegmentStatus.failed;
    if (_hasAudio(segment)) return _SegmentStatus.done;
    return _SegmentStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _status;
    final hasAudio = _hasAudio(segment);
    final settings = this.settings;
    final hasSettings = settings != null && !settings.isEmpty;
    final statusColor = switch (status) {
      _SegmentStatus.pending => context.fg.withValues(alpha: 0.12),
      _SegmentStatus.generating => AppTheme.accentColor,
      _SegmentStatus.done => context.colors.success,
      _SegmentStatus.failed => context.colors.danger,
    };
    final highlighted = focused || selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: isPlaying || selected
              ? AppTheme.accentColor.withValues(alpha: 0.10)
              : context.colors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted || isPlaying
                ? AppTheme.accentColor.withValues(alpha: focused ? 0.85 : 0.5)
                : context.fg.withValues(alpha: 0.04),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: statusColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (selecting)
                                SizedBox(
                                  width: 28,
                                  height: 24,
                                  child: Checkbox(
                                    value: selected,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) => onTap(),
                                  ),
                                )
                              else
                                _IndexBadge(index: index, status: status),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    right: 6,
                                  ),
                                  child: Text(
                                    segment.segmentText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                    maxLines: focused ? null : 3,
                                    overflow: focused
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          PhaseSpeakerLabel(label: segment.speakerLabel),
                          if (hasSettings) ...[
                            const SizedBox(height: 6),
                            _SettingsSummary(settings: settings),
                          ],
                          if (segment.error != null && !isGenerating) ...[
                            const SizedBox(height: 6),
                            Tooltip(
                              message: segment.error!,
                              child: Text(
                                segment.error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.danger.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildFooter(context, l10n, hasAudio, hasSettings),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppLocalizations l10n,
    bool hasAudio,
    bool hasSettings,
  ) {
    return Row(
      children: [
        Flexible(
          child: _VoiceChip(
            value: segment.voiceAssetId,
            assets: assets,
            onChanged: onVoiceChanged,
          ),
        ),
        const Spacer(),
        if (hasAudio && segment.audioDuration != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _formatShort(segment.audioDuration!),
              style: TextStyle(
                fontSize: 11,
                color: context.fg.withValues(alpha: 0.45),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        LiveSentencePreviewButton.phase(segment, disabled: isGenerating),
        if (isGenerating)
          const SizedBox(
            width: 34,
            height: 34,
            child: Padding(
              padding: EdgeInsets.all(9),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          _CardAction(
            tooltip: segment.audioPath != null
                ? l10n.uiRegenerate
                : l10n.uiGenerate,
            icon: segment.audioPath != null
                ? Icons.refresh_rounded
                : Icons.auto_awesome_rounded,
            color: onGenerate == null ? null : AppTheme.accentColor,
            onPressed: onGenerate,
          ),
        PopupMenuButton<String>(
          tooltip: l10n.phaseMoreActions,
          icon: Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: context.fg.withValues(alpha: 0.55),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 190),
          style: IconButton.styleFrom(
            minimumSize: const Size(34, 34),
            fixedSize: const Size(34, 34),
          ),
          onSelected: (value) => switch (value) {
            'style' => onSettings(),
            'edit' => onEditText(),
            'split' => onSplit(),
            'merge' => onMergeNext(),
            'insert' => onInsertBelow(),
            'delete' => onDelete(),
            _ => null,
          },
          itemBuilder: (context) => [
            _menuItem(
              context,
              'style',
              Icons.tune_rounded,
              l10n.uiVoiceSettings,
              highlight: hasSettings,
            ),
            _menuItem(
              context,
              'edit',
              Icons.edit_note_rounded,
              l10n.phaseEditText,
            ),
            const PopupMenuDivider(),
            _menuItem(
              context,
              'insert',
              Icons.playlist_add_rounded,
              l10n.phaseInsertBelow,
            ),
            _menuItem(
              context,
              'split',
              Icons.call_split_rounded,
              l10n.phaseSplit,
              enabled: segment.segmentText.trim().length > 1,
            ),
            _menuItem(
              context,
              'merge',
              Icons.merge_rounded,
              l10n.phaseMergeNext,
              enabled: !isLast,
            ),
            const PopupMenuDivider(),
            _menuItem(
              context,
              'delete',
              Icons.delete_outline_rounded,
              l10n.uiDeleteSegment,
              destructive: true,
            ),
          ],
        ),
        if (dragIndex != null)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: Tooltip(
              message: l10n.phaseDragToReorder,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: 28,
                  height: 34,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: context.fg.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label, {
    bool highlight = false,
    bool destructive = false,
    bool enabled = true,
  }) {
    final color = destructive
        ? context.colors.danger
        : highlight
        ? AppTheme.accentColor
        : null;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
