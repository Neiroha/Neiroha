part of 'segment_voice_panel.dart';

/// One sentence: status strip, index (or checkbox in multi-select), text,
/// style summary, error, then the voice pill and the actions.
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
      _SegmentStatus.pending => Colors.white.withValues(alpha: 0.12),
      _SegmentStatus.generating => AppTheme.accentColor,
      _SegmentStatus.done => _doneColor,
      _SegmentStatus.failed => _failedColor,
    };
    final highlighted = focused || selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: isPlaying || selected
              ? AppTheme.accentColor.withValues(alpha: 0.10)
              : AppTheme.surfaceDim,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted || isPlaying
                ? AppTheme.accentColor.withValues(alpha: focused ? 0.85 : 0.5)
                : Colors.white.withValues(alpha: 0.04),
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
                                  color: _failedColor.withValues(alpha: 0.9),
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
                color: Colors.white.withValues(alpha: 0.45),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (hasAudio)
          _CardAction(
            tooltip: isPlaying ? l10n.phaseStopPlayback : l10n.phasePlay,
            icon: isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: isPlaying ? AppTheme.accentColor : null,
            onPressed: onTogglePlay,
          ),
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
            color: Colors.white.withValues(alpha: 0.55),
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
              'style',
              Icons.tune_rounded,
              l10n.uiVoiceSettings,
              highlight: hasSettings,
            ),
            _menuItem('edit', Icons.edit_note_rounded, l10n.phaseEditText),
            const PopupMenuDivider(),
            _menuItem(
              'insert',
              Icons.playlist_add_rounded,
              l10n.phaseInsertBelow,
            ),
            _menuItem(
              'split',
              Icons.call_split_rounded,
              l10n.phaseSplit,
              enabled: segment.segmentText.trim().length > 1,
            ),
            _menuItem(
              'merge',
              Icons.merge_rounded,
              l10n.phaseMergeNext,
              enabled: !isLast,
            ),
            const PopupMenuDivider(),
            _menuItem(
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
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool highlight = false,
    bool destructive = false,
    bool enabled = true,
  }) {
    final color = destructive
        ? _failedColor
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

class _IndexBadge extends StatelessWidget {
  final int index;
  final _SegmentStatus status;

  const _IndexBadge({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      _SegmentStatus.done => (_doneColor.withValues(alpha: 0.14), _doneColor),
      _SegmentStatus.failed => (
        _failedColor.withValues(alpha: 0.14),
        _failedColor,
      ),
      _SegmentStatus.generating => (
        AppTheme.accentColor.withValues(alpha: 0.2),
        Colors.white,
      ),
      _SegmentStatus.pending => (
        Colors.white.withValues(alpha: 0.05),
        Colors.white.withValues(alpha: 0.5),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Lightweight voice selector: a pill showing the current voice that opens a
/// menu, instead of a full form dropdown per row.
class _VoiceChip extends StatelessWidget {
  static const _unassigned = '';

  final String? value;
  final List<db.VoiceAsset> assets;
  final ValueChanged<String?> onChanged;

  const _VoiceChip({
    required this.value,
    required this.assets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = assets.where((a) => a.id == value).firstOrNull;
    final assigned = current != null;
    return PopupMenuButton<String>(
      tooltip: l10n.uiVoice,
      initialValue: current?.id ?? _unassigned,
      onSelected: (id) => onChanged(id == _unassigned ? null : id),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _unassigned,
          height: 36,
          child: Text(
            l10n.uiUnassigned,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        for (final asset in assets)
          PopupMenuItem<String>(
            value: asset.id,
            height: 36,
            child: Row(
              children: [
                Icon(
                  asset.id == value
                      ? Icons.check_rounded
                      : Icons.record_voice_over_rounded,
                  size: 16,
                  color: asset.id == value
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    asset.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(
          color: assigned
              ? AppTheme.accentColor.withValues(alpha: 0.14)
              : Colors.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 14,
              color: assigned ? AppTheme.accentColor : Colors.amber,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                current?.name ?? l10n.uiVoice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: assigned
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.amber,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  const _CardAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      color: color ?? Colors.white.withValues(alpha: 0.75),
      disabledColor: Colors.white.withValues(alpha: 0.18),
      icon: Icon(icon),
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  final SegmentVoiceSettings settings;

  const _SettingsSummary({required this.settings});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (settings.voiceInstruction != null &&
          settings.voiceInstruction!.isNotEmpty)
        settings.voiceInstruction!,
      if (settings.audioTagPrefix != null &&
          settings.audioTagPrefix!.isNotEmpty)
        settings.audioTagPrefix!,
    ];
    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          size: 12,
          color: AppTheme.accentColor.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join('  |  '),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.accentColor.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VoiceDropdown extends StatelessWidget {
  final String? value;
  final List<db.VoiceAsset> assets;
  final String hintText;
  final ValueChanged<String?> onChanged;

  const _VoiceDropdown({
    required this.value,
    required this.assets,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      isExpanded: true,
      initialValue: value,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            AppLocalizations.of(context).uiUnassigned,
            style: TextStyle(fontSize: 12),
          ),
        ),
        for (final asset in assets)
          DropdownMenuItem<String>(
            value: asset.id,
            child: Text(
              asset.name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  final Widget? action;

  const _EmptyState({required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.segment_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
