import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/sidebar.dart';
import 'package:window_manager/window_manager.dart';

import 'quick_tts_screen.dart';
import 'phase_tts_screen.dart';
import 'dialog_tts_screen.dart';
import 'voice_asset_screen.dart';
import 'voice_character_screen.dart';
import 'voice_bank_screen.dart';
import 'voice_design_screen.dart';
import 'provider_screen.dart';
import 'settings_screen.dart';

final selectedTabProvider = StateProvider<NavTab>((ref) => NavTab.quickTts);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    return Scaffold(
      body: Column(
        children: [
          if (Platform.isWindows) const _WindowsTitleBar(),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  selected: selectedTab,
                  onTabChanged: (tab) =>
                      ref.read(selectedTabProvider.notifier).state = tab,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _buildPage(selectedTab),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(NavTab tab) {
    return switch (tab) {
      NavTab.quickTts => const QuickTtsScreen(key: ValueKey('quickTts')),
      NavTab.phaseTts => const PhaseTtsScreen(key: ValueKey('phaseTts')),
      NavTab.dialogTts => const DialogTtsScreen(key: ValueKey('dialogTts')),
      NavTab.voiceDesign =>
        const VoiceDesignScreen(key: ValueKey('voiceDesign')),
      NavTab.voiceAssets =>
        const VoiceAssetScreen(key: ValueKey('voiceAssets')),
      NavTab.voiceCharacters =>
        const VoiceCharacterScreen(key: ValueKey('voiceCharacters')),
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
              child: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Neiroha',
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
          _TitleBarButton(
            icon: Icons.minimize,
            onTap: windowManager.minimize,
          ),
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
              ? (widget.isClose ? Colors.red : Colors.white.withValues(alpha: 0.1))
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
