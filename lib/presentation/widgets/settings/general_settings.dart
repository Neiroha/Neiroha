import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Startup screen set to ${tab.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.home_work_rounded,
          title: 'Startup Screen',
          subtitle:
              'Choose which workspace opens when Neiroha starts. This applies on the next launch.',
          trailing: DropdownButton<NavTab>(
            value: _startupTab,
            underline: const SizedBox.shrink(),
            items: [
              for (final tab in NavTab.values)
                DropdownMenuItem(value: tab, child: Text(tab.label)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'TTS will continue when switching screens.'
              : 'Novel playback will stop when leaving the reader.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.swap_horiz_rounded,
          title: 'Keep TTS Running Across Screens',
          subtitle:
              'Useful for reading with Novel Reader while checking task progress or settings.',
          trailing: Switch(
            value: _continueAcrossScreens,
            onChanged: _loaded ? _setContinueAcrossScreens : null,
          ),
        ),
      ),
    );
  }
}
