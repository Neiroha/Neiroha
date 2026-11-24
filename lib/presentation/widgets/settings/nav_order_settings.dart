import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

import 'settings_shared.dart';

/// Drag the sidebar's pages into the order you use them.
class NavOrderSettingsCard extends ConsumerWidget {
  const NavOrderSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = navMainTabs(ref);
    final notifier = ref.read(navOrderProvider.notifier);
    final changed = !listEquals(order, NavOrder.defaults);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: Icons.view_sidebar_rounded,
              title: l10n.navOrderTitle,
              subtitle: l10n.navOrderSubtitle,
              trailing: TextButton.icon(
                onPressed: changed ? notifier.reset : null,
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
                for (final (i, tab) in order.indexed)
                  ReorderableDragStartListener(
                    key: ValueKey(tab),
                    index: i,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDim,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            Icon(tab.icon, size: 18),
                            const SizedBox(width: 12),
                            Expanded(child: Text(tab.localizedLabel(l10n))),
                            Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ],
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
