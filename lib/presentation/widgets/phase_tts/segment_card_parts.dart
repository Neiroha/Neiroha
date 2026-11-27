part of 'segment_voice_panel.dart';

// Badges, chips and small controls used by segment cards.

class _IndexBadge extends StatelessWidget {
  final int index;
  final _SegmentStatus status;

  const _IndexBadge({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      _SegmentStatus.done => (
        context.colors.success.withValues(alpha: 0.14),
        context.colors.success,
      ),
      _SegmentStatus.failed => (
        context.colors.danger.withValues(alpha: 0.14),
        context.colors.danger,
      ),
      _SegmentStatus.generating => (
        AppTheme.accentColor.withValues(alpha: 0.2),
        context.pick(dark: Colors.white, light: AppTheme.accentColor),
      ),
      _SegmentStatus.pending => (
        context.fg.withValues(alpha: 0.05),
        context.fg.withValues(alpha: 0.5),
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
              color: context.fg.withValues(alpha: 0.6),
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
                      : context.fg.withValues(alpha: 0.4),
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
              : context.colors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 14,
              color: assigned ? AppTheme.accentColor : context.colors.warning,
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
                      ? context.fg.withValues(alpha: 0.9)
                      : context.colors.warning,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: context.fg.withValues(alpha: 0.5),
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
      color: color ?? context.fg.withValues(alpha: 0.75),
      disabledColor: context.fg.withValues(alpha: 0.18),
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
              color: context.fg.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.fg.withValues(alpha: 0.35),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
