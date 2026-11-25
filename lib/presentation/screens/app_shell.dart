import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/ai/model_retirement_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/presentation/widgets/layout/windows_caption_bar.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/providers/nav_order_provider.dart';

import 'voice_bank_screen.dart';
import 'provider_screen.dart';
import 'settings_screen.dart';
import 'workspaces/workspaces_native.dart'
    if (dart.library.js_interop) 'workspaces/workspaces_web.dart';

const double _compactShellBreakpoint = 840;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<NavTab> _visitedTabs = {AppNavigationSettings.defaultStartupTab};
  Future<bool> Function()? _phaseTtsExitGuard;
  String? _lastPersistedTabName;
  DateTime? _lastAndroidBackAt;

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

    // A page hidden from the sidebar is not opened at startup.
    final layout = await ref.read(navOrderProvider.future);
    if (!mounted) return;
    final startupTab = navShownTab(
      layout,
      NavTab.fromName(lastStored) ??
          NavTab.fromName(stored) ??
          AppNavigationSettings.defaultStartupTab,
    );
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
    final playbackSourceTag = ref.watch(
      playbackNotifierProvider.select((state) => state.sourceTag),
    );
    // Dialog TTS keeps its player above the chat input, so the global bottom
    // bar is suppressed there to avoid a double UI. Phase TTS previews and
    // Voice Bank quick tests play through this bar.
    final showGlobalPlayer =
        selectedTab != NavTab.dialogTts &&
        selectedTab != NavTab.novelReader &&
        (continueTtsAcrossScreens ||
            !isNovelReaderPlaybackSource(playbackSourceTag));
    final globalPlayer = !showGlobalPlayer
        ? null
        : !kIsWeb && Platform.isWindows
        ? const PersistentAudioBar()
        : const SafeArea(top: false, child: PersistentAudioBar());

    return PopScope(
      canPop: kIsWeb || !Platform.isAndroid,
      onPopInvokedWithResult: (didPop, _) {
        if (!kIsWeb && !didPop && Platform.isAndroid) {
          unawaited(_handleAndroidBackIntent());
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactShellBreakpoint;
          final chrome = ref.watch(windowChromeProvider);
          final macInset = chrome == WindowChrome.macos
              ? _macTitleBarInset
              : 0.0;
          final windows = chrome == WindowChrome.windows;
          return Scaffold(
            key: _scaffoldKey,
            drawerEnableOpenDragGesture: compact,
            drawer: compact
                ? AppNavigationDrawer(
                    selected: selectedTab,
                    onTabChanged: (tab) => unawaited(_switchFromDrawer(tab)),
                  )
                : null,
            body: Column(
              children: [
                if (compact && windows)
                  WindowsCaptionBar(
                    title: AppLocalizations.of(context).appTitle,
                    color: AppTheme.sidebarBg,
                  ),
                if (compact && macInset > 0)
                  Container(height: macInset, color: AppTheme.sidebarBg),
                if (compact)
                  _MobileTopBar(
                    selectedTab: selectedTab,
                    onMenuPressed: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),
                Expanded(
                  child: compact
                      ? _buildPageStack(selectedTab)
                      : SafeArea(
                          child: Row(
                            children: [
                              Sidebar(
                                selected: selectedTab,
                                topInset: macInset,
                                onTabChanged: (tab) =>
                                    unawaited(_switchTab(tab)),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              // Pages run to the top edge: the traffic
                              // lights sit over the sidebar, and page
                              // headers double as the window's drag area.
                              // The banner and player stay right of the
                              // sidebar so it keeps the full height.
                              Expanded(
                                child: Column(
                                  children: [
                                    // Windows: caption buttons right of the
                                    // sidebar, as macOS keeps its lights
                                    // over it.
                                    if (windows) const WindowsCaptionBar(),
                                    Expanded(
                                      child: _buildPageStack(selectedTab),
                                    ),
                                    const RetirementBanner(),
                                    ?globalPlayer,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (compact) ...[const RetirementBanner(), ?globalPlayer],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAndroidBackIntent() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted || AppBackIntent.consumeChildHandledRecently()) return;

    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastAndroidBackAt != null &&
        now.difference(_lastAndroidBackAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      await SystemNavigator.pop();
      return;
    }

    _lastAndroidBackAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pressBackAgainToExit),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _switchFromDrawer(NavTab tab) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    await _switchTab(tab);
  }

  Future<void> _switchTab(NavTab tab) async {
    final current = ref.read(selectedTabProvider);
    if (current == tab) return;
    _lastAndroidBackAt = null;
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
      NavTab.voiceBank => const VoiceBankScreen(key: ValueKey('voiceBank')),
      NavTab.providers => const ProviderScreen(key: ValueKey('providers')),
      NavTab.settings => const SettingsScreen(key: ValueKey('settings')),
      _ => buildWorkspace(
        context,
        tab,
        active: active,
        onPhaseExitGuardChanged: (guard) => _phaseTtsExitGuard = guard,
      ),
    };
  }
}

class _MobileTopBar extends StatelessWidget {
  final NavTab selectedTab;
  final VoidCallback onMenuPressed;

  const _MobileTopBar({required this.selectedTab, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        color: AppTheme.sidebarBg,
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: onMenuPressed,
              icon: const Icon(Icons.menu_rounded),
            ),
            Expanded(
              child: Text(
                selectedTab.localizedLabel(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// macOS draws its traffic lights over the content (transparent title bar,
/// see MainFlutterWindow.swift); the sidebar keeps that strip free.
const double _macTitleBarInset = 28;
