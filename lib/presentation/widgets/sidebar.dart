import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

const _bottomTabs = [NavTab.providers, NavTab.settings];

/// Desktop navigation rail. Drag its right edge (or use the bottom toggle)
/// to widen it; past [_labelsFrom] it shows each page's name. The width is
/// kept across launches.
class Sidebar extends ConsumerStatefulWidget {
  final NavTab selected;
  final ValueChanged<NavTab> onTabChanged;

  /// Space kept free at the top for the macOS traffic lights.
  final double topInset;

  const Sidebar({
    super.key,
    required this.selected,
    required this.onTabChanged,
    this.topInset = 0,
  });

  static const widthSetting = 'ui.sidebar.width';

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

const _railWidth = AppTheme.sidebarWidth;
const _labelsFrom = 132.0;
const _maxWidth = 260.0;
const _openWidth = 196.0;

class _SidebarState extends ConsumerState<Sidebar> {
  double _width = _railWidth;

  /// Width to return to when the toggle opens the rail.
  double _lastOpen = _openWidth;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await ref
          .read(databaseProvider)
          .getSetting(Sidebar.widthSetting);
      final w = double.tryParse(saved ?? '');
      if (w != null && mounted) setState(() => _width = _snap(w));
    } catch (_) {
      // Keep the rail when settings are unavailable.
    }
  }

  static double _snap(double w) =>
      w < _labelsFrom ? _railWidth : w.clamp(_labelsFrom, _maxWidth);

  void _save() {
    if (_width > _railWidth) _lastOpen = _width;
    unawaited(
      ref
          .read(databaseProvider)
          .setSetting(Sidebar.widthSetting, _width.toStringAsFixed(0))
          .catchError((_) {}),
    );
  }

  void _toggle() {
    setState(() => _width = _width > _railWidth ? _railWidth : _lastOpen);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final open = _width >= _labelsFrom;
    Widget button(NavTab tab) => _SidebarButton(
      tab: tab,
      open: open,
      isSelected: widget.selected == tab,
      onTap: () => widget.onTabChanged(tab),
    );
    return SizedBox(
      width: _width,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: context.colors.sidebar,
              child: Column(
                children: [
                  // Traffic-light strip and logo move the window on macOS.
                  WindowDragArea(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 8 + widget.topInset,
                        bottom: 10,
                        left: open ? 16 : 0,
                      ),
                      child: Row(
                        mainAxisAlignment: open
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SvgPicture.asset(
                              'assets/icon/neiroha_logo.svg',
                              width: 38,
                              height: 38,
                            ),
                          ),
                          if (open) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                l10n.appTitle,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Divider(indent: 12, endIndent: 12),
                  const SizedBox(height: 4),
                  // Main tabs scroll when the window is too short for all.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [for (final t in navMainTabs(ref)) button(t)],
                      ),
                    ),
                  ),
                  // Providers + Settings pinned at bottom.
                  const Divider(indent: 12, endIndent: 12),
                  const SizedBox(height: 4),
                  for (final t in _bottomTabs) button(t),
                  IconButton(
                    tooltip: open ? l10n.sidebarCollapse : l10n.sidebarExpand,
                    onPressed: _toggle,
                    icon: Icon(
                      open
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                      size: 18,
                      color: context.fg.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: _ResizeEdge(
              onDrag: (dx) => setState(
                () => _width = (_width + dx).clamp(_railWidth, _maxWidth),
              ),
              onEnd: () {
                setState(() => _width = _snap(_width));
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeEdge extends StatefulWidget {
  const _ResizeEdge({required this.onDrag, required this.onEnd});
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;

  @override
  State<_ResizeEdge> createState() => _ResizeEdgeState();
}

class _ResizeEdgeState extends State<_ResizeEdge> {
  bool _active = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    onEnter: (_) => setState(() => _active = true),
    onExit: (_) => setState(() => _active = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
      onHorizontalDragEnd: (_) => widget.onEnd(),
      child: SizedBox(
        width: 6,
        child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _active ? 3 : 0,
            color: AppTheme.accentColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    ),
  );
}

class AppNavigationDrawer extends ConsumerWidget {
  final NavTab selected;
  final ValueChanged<NavTab> onTabChanged;

  const AppNavigationDrawer({
    super.key,
    required this.selected,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      backgroundColor: context.colors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SvgPicture.asset(
                      'assets/icon/neiroha_logo.svg',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.appTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final tab in navMainTabs(ref))
                    _DrawerTabTile(
                      tab: tab,
                      selected: tab == selected,
                      onTap: () => onTabChanged(tab),
                    ),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  for (final tab in _bottomTabs)
                    _DrawerTabTile(
                      tab: tab,
                      selected: tab == selected,
                      onTap: () => onTabChanged(tab),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTabTile extends StatelessWidget {
  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerTabTile({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = selected
        ? context.fg.withValues(alpha: 0.95)
        : context.fg.withValues(alpha: 0.72);
    return ListTile(
      selected: selected,
      leading: Icon(
        tab.icon,
        color: selected ? AppTheme.accentColor : foreground,
      ),
      title: Text(
        tab.localizedLabel(l10n),
        style: TextStyle(
          color: foreground,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selectedTileColor: AppTheme.accentColor.withValues(alpha: 0.14),
      onTap: onTap,
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final NavTab tab;
  final bool open;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.tab,
    required this.open,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = isSelected
        ? AppTheme.accentColor
        : context.fg.withValues(alpha: open ? 0.6 : 0.4);
    final label = tab.localizedLabel(l10n);
    final body = Padding(
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: open ? 12 : 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: open ? double.infinity : 48,
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: open ? 12 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            border: isSelected
                ? Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: open
              ? Row(
                  children: [
                    Icon(tab.icon, size: 20, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? context.fg.withValues(alpha: 0.95)
                              : context.fg.withValues(alpha: 0.7),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              : Icon(tab.icon, size: 20, color: color),
        ),
      ),
    );
    // The label is on screen when open; the tooltip only helps the rail.
    return open
        ? body
        : Tooltip(
            message: label,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 400),
            child: body,
          );
  }
}
