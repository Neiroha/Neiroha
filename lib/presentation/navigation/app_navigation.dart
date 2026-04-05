import 'package:flutter/material.dart';

enum NavTab {
  quickTts(Icons.volume_up_rounded, 'Quick TTS'),
  phaseTts(Icons.auto_stories_rounded, 'Phase TTS'),
  dialogTts(Icons.forum_rounded, 'Dialog TTS'),
  voiceCharacters(Icons.person_rounded, 'Voice Characters'),
  voiceBank(Icons.people_alt_rounded, 'Voice Bank'),
  voiceDesign(Icons.auto_fix_high_rounded, 'Voice Design'),
  providerTest(Icons.science_rounded, 'Provider Test'),
  providers(Icons.dns_rounded, 'Providers'),
  settings(Icons.settings_rounded, 'Settings');

  final IconData icon;
  final String label;
  const NavTab(this.icon, this.label);
}
