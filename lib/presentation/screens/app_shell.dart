import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:window_manager/window_manager.dart';

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
    final playbackSourceTag = ref.watch(
      playbackNotifierProvider.select((state) => state.sourceTag),
    );
    // Dialog/Phase render their own inline players, so the global bottom bar
    // is suppressed there to avoid a double UI.
    // Voice Bank quick tests also render inline above the test input.
    final showGlobalPlayer =
        selectedTab != NavTab.dialogTts &&
        selectedTab != NavTab.phaseTts &&
        selectedTab != NavTab.novelReader &&
        (continueTtsAcrossScreens ||
            !isNovelReaderPlaybackSource(playbackSourceTag)) &&
        !(selectedTab == NavTab.voiceBank &&
            playbackSourceTag == voiceBankQuickTestPlaybackSource);

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
                if (!kIsWeb && Platform.isWindows) const _WindowsTitleBar(),
                if (compact && _macTitleBarInset > 0)
                  Container(
                    height: _macTitleBarInset,
                    color: AppTheme.sidebarBg,
                  ),
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
                                topInset: _macTitleBarInset,
                                onTabChanged: (tab) =>
                                    unawaited(_switchTab(tab)),
                              ),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: _macTitleBarInset,
                                  ),
                                  child: _buildPageStack(selectedTab),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (showGlobalPlayer)
                  !kIsWeb && Platform.isWindows
                      ? const PersistentAudioBar()
                      : const SafeArea(top: false, child: PersistentAudioBar()),
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
/// see MainFlutterWindow.swift); keep that strip free of controls.
final double _macTitleBarInset = !kIsWeb && Platform.isMacOS ? 28 : 0;

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
