import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/l10n/app_locale.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';

class LanguageSettingsCard extends ConsumerWidget {
  const LanguageSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleProvider);
    final current = AppLocaleSettings.storageValue(locale);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.translate_rounded,
          title: l10n.languageTitle,
          subtitle: l10n.languageSubtitle,
          trailing: DropdownButton<String>(
            value: current,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
              DropdownMenuItem(value: 'zh', child: Text(l10n.languageChinese)),
            ],
            onChanged: (value) async {
              if (value == null || value == current) return;
              final nextLocale = AppLocaleSettings.parse(value);
              ref.read(appLocaleProvider.notifier).state = nextLocale;
              await ref
                  .read(databaseProvider)
                  .setSetting(
                    AppLocaleSettings.localeKey,
                    AppLocaleSettings.storageValue(nextLocale),
                  );
              if (!context.mounted) return;
              final nextL10n = AppLocalizations.of(context);
              final label = value == 'zh'
                  ? nextL10n.languageChinese
                  : nextL10n.languageEnglish;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(nextL10n.languageSaved(label))),
              );
            },
          ),
        ),
      ),
    );
  }
}

class StartupSettingsCard extends ConsumerStatefulWidget {
  const StartupSettingsCard({super.key});

  @override
  ConsumerState<StartupSettingsCard> createState() =>
      _StartupSettingsCardState();
}

class _StartupSettingsCardState extends ConsumerState<StartupSettingsCard> {
  NavTab _startupTab = NavTab.voiceBank;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppNavigationSettings.startupTabKey);
    if (!mounted) return;
    setState(() {
      _startupTab = NavTab.fromName(stored) ?? NavTab.voiceBank;
      _loaded = true;
    });
  }

  Future<void> _setStartupTab(NavTab tab) async {
    setState(() => _startupTab = tab);
    await ref
        .read(databaseProvider)
        .setSetting(AppNavigationSettings.startupTabKey, tab.name);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.startupScreenSaved(tab.localizedLabel(l10n))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.home_work_rounded,
          title: l10n.startupScreenTitle,
          subtitle: l10n.startupScreenSubtitle,
          trailing: DropdownButton<NavTab>(
            value: _startupTab,
            underline: const SizedBox.shrink(),
            items: [
              for (final tab in NavTab.values)
                DropdownMenuItem(
                  value: tab,
                  child: Text(tab.localizedLabel(l10n)),
                ),
            ],
            onChanged: !_loaded
                ? null
                : (tab) {
                    if (tab != null && tab != _startupTab) {
                      _setStartupTab(tab);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

class TaskBehaviorSettingsCard extends ConsumerStatefulWidget {
  const TaskBehaviorSettingsCard({super.key});

  @override
  ConsumerState<TaskBehaviorSettingsCard> createState() =>
      _TaskBehaviorSettingsCardState();
}

class _TaskBehaviorSettingsCardState
    extends ConsumerState<TaskBehaviorSettingsCard> {
  bool _loaded = false;
  bool _continueAcrossScreens =
      AppBehaviorSettings.defaultContinueTtsAcrossScreens;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppBehaviorSettings.continueTtsAcrossScreensKey);
    final enabled = AppBehaviorSettings.parseBool(
      stored,
      defaultValue: AppBehaviorSettings.defaultContinueTtsAcrossScreens,
    );
    if (!mounted) return;
    ref.read(continueTtsAcrossScreensProvider.notifier).state = enabled;
    setState(() {
      _continueAcrossScreens = enabled;
      _loaded = true;
    });
  }

  Future<void> _setContinueAcrossScreens(bool enabled) async {
    setState(() => _continueAcrossScreens = enabled);
    ref.read(continueTtsAcrossScreensProvider.notifier).state = enabled;
    await ref
        .read(databaseProvider)
        .setSetting(
          AppBehaviorSettings.continueTtsAcrossScreensKey,
          enabled ? 'true' : '',
        );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? l10n.keepTtsRunningEnabled : l10n.keepTtsRunningDisabled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.swap_horiz_rounded,
          title: l10n.keepTtsRunningTitle,
          subtitle: l10n.keepTtsRunningSubtitle,
          trailing: Switch(
            value: _continueAcrossScreens,
            onChanged: _loaded ? _setContinueAcrossScreens : null,
          ),
        ),
      ),
    );
  }
}
