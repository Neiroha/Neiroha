import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme_mode.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';

/// Light, dark, or following the system.
class ThemeSettingsCard extends ConsumerWidget {
  const ThemeSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(appThemeModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SettingsRow(
          icon: Icons.palette_rounded,
          title: l10n.themeSettingsTitle,
          subtitle: l10n.themeSettingsSubtitle,
          trailing: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                label: Text(l10n.themeModeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_rounded, size: 18),
                label: Text(l10n.themeModeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded, size: 18),
                label: Text(l10n.themeModeDark),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (picked) async {
              final next = picked.single;
              ref.read(appThemeModeProvider.notifier).state = next;
              await ref
                  .read(databaseProvider)
                  .setSetting(
                    AppThemeSettings.themeModeKey,
                    AppThemeSettings.storageValue(next),
                  );
            },
          ),
        ),
      ),
    );
  }
}
