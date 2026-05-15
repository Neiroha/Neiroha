import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/settings/settings_sections.dart';

const double _settingsWideBreakpoint = 840;
const double _settingsInitialRailFraction = 0.22;
const double _settingsRailMinWidth = 280;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(settingsSectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _settingsWideBreakpoint;
        if (isWide) {
          return HorizontalResizableSplitPane(
            initialLeftFraction: _settingsInitialRailFraction,
            minPaneWidth: _settingsRailMinWidth,
            left: SettingsSectionRail(
              selected: selectedSection,
              onSelected: (section) =>
                  ref.read(settingsSectionProvider.notifier).state = section,
            ),
            right: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0F0F14)),
              child: SettingsSectionContent(section: selectedSection),
            ),
          );
        }

        return Column(
          children: [
            SettingsCompactPicker(
              selected: selectedSection,
              onSelected: (section) =>
                  ref.read(settingsSectionProvider.notifier).state = section,
            ),
            const Divider(height: 1),
            Expanded(child: SettingsSectionContent(section: selectedSection)),
          ],
        );
      },
    );
  }
}
