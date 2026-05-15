import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'dialog_tts_screen.dart';
import 'novel_reader_screen.dart';
import 'phase_tts_screen.dart';
import 'video_dub_screen.dart';
import 'voice_asset_screen.dart';
import 'voice_bank_screen.dart';
import 'provider_screen.dart';
import 'settings_screen.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Set<NavTab> _visitedTabs = {AppNavigationSettings.defaultStartupTab};
  PhaseTtsExitGuard? _phaseTtsExitGuard;
  String? _lastPersistedTabName;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStartupTab);
    Future.microtask(_loadAppBehaviorSettings);
  }

  Future<void> _loadStartupTab() async {
    final db = ref.read(databaseProvider);
    final stored = await db.getSetting(AppNavigationSettings.startupTabKey);
    final lastStored = AppNavigationSettings.isLastStartupValue(stored)
        ? await db.getSetting(AppNavigationSettings.lastTabKey)
        : null;
    if (!mounted) return;

    final startupTab =
        NavTab.fromName(lastStored) ??
        NavTab.fromName(stored) ??
        AppNavigationSettings.defaultStartupTab;
    _visitedTabs.add(startupTab);
    ref.read(selectedTabProvider.notifier).state = startupTab;
    unawaited(_storeLastTab(startupTab));
  }

  Future<void> _loadAppBehaviorSettings() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppBehaviorSettings.continueTtsAcrossScreensKey);
    if (!mounted) return;
    ref
        .read(continueTtsAcrossScreensProvider.notifier)
        .state = AppBehaviorSettings.parseBool(
      stored,
      defaultValue: AppBehaviorSettings.defaultContinueTtsAcrossScreens,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NavTab>(selectedTabProvider, (_, next) {
      unawaited(_storeLastTab(next));
    });
    final selectedTab = ref.watch(selectedTabProvider);
    final continueTtsAcrossScreens = ref.watch(
      continueTtsAcrossScreensProvider,
    );
    _visitedTabs.add(selectedTab);
    final playback = ref.watch(playbackNotifierProvider);
    // Dialog/Phase render their own inline players, so the global bottom bar
    // is suppressed there to avoid a double UI.
    // Voice Bank quick tests also render inline above the test input.
    final showGlobalPlayer =
        selectedTab != NavTab.dialogTts &&
        selectedTab != NavTab.phaseTts &&
        selectedTab != NavTab.novelReader &&
        (continueTtsAcrossScreens ||
            !isNovelReaderPlaybackSource(playback.sourceTag)) &&
        !(selectedTab == NavTab.voiceBank &&
            playback.sourceTag == voiceBankQuickTestPlaybackSource);

    return Scaffold(
      body: Column(
        children: [
          if (Platform.isWindows) const _WindowsTitleBar(),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  selected: selectedTab,
                  onTabChanged: (tab) => unawaited(_switchTab(tab)),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _buildPageStack(selectedTab)),
              ],
            ),
          ),
          if (showGlobalPlayer) const PersistentAudioBar(),
        ],
      ),
    );
  }

  Future<void> _switchTab(NavTab tab) async {
    final current = ref.read(selectedTabProvider);
    if (current == tab) return;
    if (current == NavTab.phaseTts) {
      final guard = _phaseTtsExitGuard;
      if (guard != null && !await guard()) return;
    }
    if (current == NavTab.novelReader &&
        !ref.read(continueTtsAcrossScreensProvider)) {
      await ref
          .read(playbackNotifierProvider.notifier)
          .stopIfSourceTagPrefix(novelReaderPlaybackSource);
    }
    ref.read(selectedTabProvider.notifier).state = tab;
  }

  Future<void> _storeLastTab(NavTab tab) async {
    if (_lastPersistedTabName == tab.name) return;
    _lastPersistedTabName = tab.name;
    await ref
        .read(databaseProvider)
        .setSetting(AppNavigationSettings.lastTabKey, tab.name);
  }

  Widget _buildPageStack(NavTab selectedTab) {
    final tabs = NavTab.values.where(_visitedTabs.contains).toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final tab in tabs)
          Offstage(
            offstage: selectedTab != tab,
            child: TickerMode(
              enabled: selectedTab == tab,
              child: KeyedSubtree(
                key: ValueKey('tab-${tab.name}'),
                child: _buildPage(tab, active: selectedTab == tab),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPage(NavTab tab, {required bool active}) {
    return switch (tab) {
      NavTab.phaseTts => PhaseTtsScreen(
        key: const ValueKey('phaseTts'),
        onExitGuardChanged: (guard) => _phaseTtsExitGuard = guard,
      ),
      NavTab.novelReader => const NovelReaderScreen(
        key: ValueKey('novelReader'),
      ),
      NavTab.dialogTts => const DialogTtsScreen(key: ValueKey('dialogTts')),
      NavTab.videoDub => VideoDubScreen(
        key: const ValueKey('videoDub'),
        active: active,
      ),
      NavTab.voiceAssets => const VoiceAssetScreen(
        key: ValueKey('voiceAssets'),
      ),
      NavTab.voiceBank => const VoiceBankScreen(key: ValueKey('voiceBank')),
      NavTab.providers => const ProviderScreen(key: ValueKey('providers')),
      NavTab.settings => const SettingsScreen(key: ValueKey('settings')),
    };
  }
}

class _WindowsTitleBar extends StatelessWidget {
  const _WindowsTitleBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppTheme.sidebarBg,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              child: Padding(
                padding: EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppLocalizations.of(context).appTitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _TitleBarButton(icon: Icons.minimize, onTap: windowManager.minimize),
          _TitleBarButton(
            icon: Icons.crop_square,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _TitleBarButton(
            icon: Icons.close,
            onTap: windowManager.close,
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _TitleBarButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: _hovering
              ? (widget.isClose
                    ? Colors.red
                    : Colors.white.withValues(alpha: 0.1))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: Colors.white.withValues(alpha: _hovering ? 0.9 : 0.6),
          ),
        ),
      ),
    );
  }
}
