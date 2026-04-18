import 'package:flutter/material.dart';

enum NavTab {
  phaseTts(Icons.auto_stories_rounded, 'Phase TTS'),
  dialogTts(Icons.forum_rounded, 'Dialog TTS'),
  voiceDesign(Icons.auto_fix_high_rounded, 'Voice Design'),
  voiceAssets(Icons.library_music_rounded, 'Voice Assets'),
  voiceBank(Icons.people_alt_rounded, 'Voice Bank'),
  providers(Icons.dns_rounded, 'Providers'),
  settings(Icons.settings_rounded, 'Settings');

  final IconData icon;
  final String label;
  const NavTab(this.icon, this.label);
}
