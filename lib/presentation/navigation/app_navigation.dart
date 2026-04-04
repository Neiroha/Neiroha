import 'package:flutter/material.dart';

enum NavTab {
  quickTts(Icons.volume_up_rounded, 'Quick TTS'),
  phaseTts(Icons.auto_stories_rounded, 'Phase TTS'),
  dialogTts(Icons.forum_rounded, 'Dialog TTS'),
  voiceAssets(Icons.record_voice_over_rounded, 'Voice Assets'),
  voiceDesign(Icons.auto_fix_high_rounded, 'Voice Design'),
  providers(Icons.dns_rounded, 'Providers'),
  settings(Icons.settings_rounded, 'Settings');

  final IconData icon;
  final String label;
  const NavTab(this.icon, this.label);
}
