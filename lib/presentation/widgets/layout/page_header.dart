import 'package:flutter/material.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

import 'window_drag_area.dart';

/// Compact top row shared by the workspace pages: optional back button,
/// icon, title and a one-line description on the left, actions on the right.
/// 52 pt tall and draggable, so on macOS it doubles as the window title bar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onBack,
    this.backTooltip,
    this.center,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onBack;
  final String? backTooltip;

  /// Shown between the title and the actions (a mode switch, a status chip).
  final Widget? center;
  final List<Widget> actions;

  static const height = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WindowDragArea(
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 6, 6, 12, 6),
        child: Theme(
          data: theme.copyWith(visualDensity: VisualDensity.compact),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: backTooltip,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              if (icon != null) ...[
                Icon(icon, color: AppTheme.accentColor, size: 18),
                const SizedBox(width: 10),
              ],
              _TitleSlot(
                fill: subtitle == null,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.fg.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
              if (center != null) ...[const SizedBox(width: 12), center!],
              const SizedBox(width: 8),
              for (final (i, action) in actions.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleSlot extends StatelessWidget {
  const _TitleSlot({required this.fill, required this.child});
  final bool fill;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      fill ? Expanded(child: child) : Flexible(flex: 0, child: child);
}
