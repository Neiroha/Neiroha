import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final NavTab selected;
  final ValueChanged<NavTab> onTabChanged;

  const Sidebar({
    super.key,
    required this.selected,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Tabs shown in main area (top)
    // NOTE: voiceDesign is hidden until a voice design model interface is wired up.
    const mainTabs = [
      NavTab.quickTts,
      NavTab.phaseTts,
      NavTab.dialogTts,
      NavTab.voiceAssets,
      NavTab.voiceBank,
    ];

    // Tabs pinned at the bottom (providers + settings)
    const bottomTabs = [
      NavTab.providers,
      NavTab.settings,
    ];

    return Container(
      width: AppTheme.sidebarWidth,
      color: AppTheme.sidebarBg,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SvgPicture.asset(
              'assets/neiroha_logo.svg',
              width: 42,
              height: 42,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(indent: 12, endIndent: 12),
          const SizedBox(height: 4),

          // Main nav tabs
          for (final tab in mainTabs)
            _SidebarButton(
              tab: tab,
              isSelected: selected == tab,
              onTap: () => onTabChanged(tab),
            ),

          const Spacer(),

          // Providers + Settings pinned at bottom
          const Divider(indent: 12, endIndent: 12),
          const SizedBox(height: 4),
          for (final tab in bottomTabs)
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
    return Tooltip(
      message: tab.label,
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
            height: 44,
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
