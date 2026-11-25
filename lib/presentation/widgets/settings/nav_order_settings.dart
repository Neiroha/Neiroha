import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

import 'settings_shared.dart';

/// Drag the sidebar's pages into the order you use them, and hide the
/// ones you never open.
class NavOrderSettingsCard extends ConsumerWidget {
  const NavOrderSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout =
        ref.watch(navOrderProvider).value ?? const NavLayout(NavOrder.defaults);
    final notifier = ref.read(navOrderProvider.notifier);
    final dim = Colors.white.withValues(alpha: 0.4);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: Icons.view_sidebar_rounded,
              title: l10n.navOrderTitle,
              subtitle: layout.hidden.isEmpty
                  ? l10n.navOrderSubtitle
                  : '${l10n.navOrderSubtitle}\n'
                        '${l10n.navOrderHiddenCount(layout.hidden.length)}',
              trailing: TextButton.icon(
                onPressed: layout.isDefault ? null : notifier.reset,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(l10n.navOrderReset),
              ),
            ),
            const SizedBox(height: 4),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: notifier.move,
              children: [
                for (final (i, tab) in layout.order.indexed)
                  ReorderableDragStartListener(
                    key: ValueKey(tab),
                    index: i,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _NavRow(
                          tab: tab,
                          position: i + 1,
                          hidden: layout.hidden.contains(tab),
                          dim: dim,
                          onHidden: (hidden) => notifier.setHidden(tab, hidden),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.tab,
    required this.position,
    required this.hidden,
    required this.dim,
    required this.onHidden,
  });

  final NavTab tab;
  final int position;
  final bool hidden;
  final Color dim;
  final ValueChanged<bool> onHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = tab.localizedLabel(l10n);
    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: hidden ? 0.45 : 1,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$position',
                    style: TextStyle(fontSize: 12, color: dim),
                  ),
                ),
                Icon(tab.icon, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: hidden
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                ),
                if (hidden)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      l10n.navOrderHidden,
                      style: TextStyle(fontSize: 12, color: dim),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: hidden ? l10n.navOrderShow(label) : l10n.navOrderHide(label),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          color: hidden ? dim : null,
          icon: Icon(
            hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
          onPressed: () => onHidden(!hidden),
        ),
        Icon(Icons.drag_indicator_rounded, size: 18, color: dim),
      ],
    );
  }
}
