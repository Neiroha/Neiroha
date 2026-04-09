import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/presentation/navigation/app_navigation.dart';
import 'package:q_vox_lab/presentation/widgets/sidebar.dart';

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
      body: Row(
        children: [
          // Sidebar (no API toggle here anymore — moved to Settings)
          Sidebar(
            selected: selectedTab,
            onTabChanged: (tab) =>
                ref.read(selectedTabProvider.notifier).state = tab,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _buildPage(selectedTab),
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
