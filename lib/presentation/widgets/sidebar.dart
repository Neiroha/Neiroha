import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';

const _mainTabs = [
  NavTab.novelReader,
  NavTab.dialogTts,
  NavTab.phaseTts,
  NavTab.videoDub,
  NavTab.subtitles,
  NavTab.music,
  NavTab.voiceAssets,
  NavTab.voiceBank,
];

const _bottomTabs = [NavTab.providers, NavTab.settings];

class Sidebar extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.sidebarWidth,
      color: AppTheme.sidebarBg,
      child: Column(
        children: [
          // Traffic-light strip and logo move the window on macOS.
          WindowDragArea(
            child: Padding(
              padding: EdgeInsets.only(top: 8 + topInset, bottom: 10),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SvgPicture.asset(
                    'assets/icon/neiroha_logo.svg',
                    width: 38,
                    height: 38,
                  ),
                ),
              ),
            ),
          ),
          const Divider(indent: 12, endIndent: 12),
          const SizedBox(height: 4),

          // Main nav tabs scroll when the window is too short for all of them.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final tab in _mainTabs)
                    _SidebarButton(
                      tab: tab,
                      isSelected: selected == tab,
                      onTap: () => onTabChanged(tab),
                    ),
                ],
              ),
            ),
          ),

          // Providers + Settings pinned at bottom
          const Divider(indent: 12, endIndent: 12),
          const SizedBox(height: 4),
          for (final tab in _bottomTabs)
            _SidebarButton(
              tab: tab,
              isSelected: selected == tab,
              onTap: () => onTabChanged(tab),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  final NavTab selected;
  final ValueChanged<NavTab> onTabChanged;

  const AppNavigationDrawer({
    super.key,
    required this.selected,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      backgroundColor: AppTheme.sidebarBg,
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
                  for (final tab in _mainTabs)
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
        ? Colors.white.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.72);
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
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: tab.localizedLabel(l10n),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 48,
            height: 40,
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
            child: Icon(
              tab.icon,
              size: 20,
              color: isSelected
                  ? AppTheme.accentColor
                  : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
