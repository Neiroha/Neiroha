import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavTab {
  novelReader(Icons.menu_book_rounded, 'Novel Reader'),
  dialogTts(Icons.forum_rounded, 'Dialog TTS'),
  phaseTts(Icons.auto_stories_rounded, 'Phase TTS'),
  videoDub(Icons.movie_filter_rounded, 'Video Dub'),
  voiceAssets(Icons.library_music_rounded, 'Voice Assets'),
  voiceBank(Icons.people_alt_rounded, 'Voice Bank'),
  providers(Icons.dns_rounded, 'Providers'),
  settings(Icons.settings_rounded, 'Settings');

  final IconData icon;
  final String label;
  const NavTab(this.icon, this.label);

  static NavTab? fromName(String? name) {
    if (name == null) return null;
    for (final tab in NavTab.values) {
      if (tab.name == name) return tab;
    }
    return null;
  }
}

enum SettingsSection {
  general(Icons.tune_rounded, 'General', 'Startup and workspace behavior'),
  api(
    Icons.power_settings_new_rounded,
    'API Server',
    'Local middleware endpoint and access controls',
  ),
  storage(
    Icons.storage_rounded,
    'Storage',
    'Data roots, disk sync and archive cleanup',
  ),
  media(
    Icons.movie_filter_rounded,
    'Media Tools',
    'FFmpeg detection and export defaults',
  ),
  about(Icons.info_outline_rounded, 'About', 'Version and app information');

  final IconData icon;
  final String label;
  final String description;
  const SettingsSection(this.icon, this.label, this.description);
}

class AppNavigationSettings {
  static const startupTabKey = 'app.startupTab';

  const AppNavigationSettings._();
}

final selectedTabProvider = StateProvider<NavTab>((ref) => NavTab.voiceBank);

final settingsSectionProvider = StateProvider<SettingsSection>(
  (ref) => SettingsSection.general,
);
