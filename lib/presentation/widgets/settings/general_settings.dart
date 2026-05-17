import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/l10n/app_locale.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_font.dart';
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

class FontSettingsCard extends ConsumerStatefulWidget {
  const FontSettingsCard({super.key});

  @override
  ConsumerState<FontSettingsCard> createState() => _FontSettingsCardState();
}

class _FontSettingsCardState extends ConsumerState<FontSettingsCard> {
  AppFontMode _fontMode = AppFontSettings.defaultMode;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppFontSettings.fontModeKey);
    final mode = AppFontMode.parse(stored);
    if (!mounted) return;
    ref.read(appFontModeProvider.notifier).state = mode;
    setState(() {
      _fontMode = mode;
      _loaded = true;
    });
  }

  Future<void> _setFontMode(AppFontMode mode) async {
    setState(() => _fontMode = mode);
    ref.read(appFontModeProvider.notifier).state = mode;
    await ref
        .read(databaseProvider)
        .setSetting(AppFontSettings.fontModeKey, mode.storageValue);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.fontModeSaved(_fontModeLabel(l10n, mode)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.font_download_rounded,
          title: l10n.fontSettingsTitle,
          subtitle: l10n.fontSettingsSubtitle,
          trailing: DropdownButton<AppFontMode>(
            value: _fontMode,
            underline: const SizedBox.shrink(),
            items: [
              for (final mode in AppFontMode.values)
                DropdownMenuItem(
                  value: mode,
                  child: Text(_fontModeLabel(l10n, mode)),
                ),
            ],
            onChanged: !_loaded
                ? null
                : (mode) {
                    if (mode != null && mode != _fontMode) {
                      _setFontMode(mode);
                    }
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
  String _startupValue = AppNavigationSettings.defaultStartupTab.name;
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
    final value = AppNavigationSettings.isLastStartupValue(stored)
        ? AppNavigationSettings.startupLastValue
        : (NavTab.fromName(stored) ?? AppNavigationSettings.defaultStartupTab)
              .name;
    if (!mounted) return;
    setState(() {
      _startupValue = value;
      _loaded = true;
    });
  }

  Future<void> _setStartupValue(String value) async {
    setState(() => _startupValue = value);
    await ref
        .read(databaseProvider)
        .setSetting(AppNavigationSettings.startupTabKey, value);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.startupScreenSaved(_startupLabel(l10n, value))),
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
          trailing: DropdownButton<String>(
            value: _startupValue,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: AppNavigationSettings.startupLastValue,
                child: Text(l10n.startupLastPage),
              ),
              for (final tab in NavTab.values)
                DropdownMenuItem(
                  value: tab.name,
                  child: Text(tab.localizedLabel(l10n)),
                ),
            ],
            onChanged: !_loaded
                ? null
                : (value) {
                    if (value != null && value != _startupValue) {
                      _setStartupValue(value);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

String _fontModeLabel(AppLocalizations l10n, AppFontMode mode) {
  return switch (mode) {
    AppFontMode.appDefault => l10n.fontModeAppDefault,
    AppFontMode.system => l10n.fontModeSystem,
  };
}

String _startupLabel(AppLocalizations l10n, String value) {
  if (value == AppNavigationSettings.startupLastValue) {
    return l10n.startupLastPage;
  }
  final tab = NavTab.fromName(value) ?? AppNavigationSettings.defaultStartupTab;
  return tab.localizedLabel(l10n);
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
