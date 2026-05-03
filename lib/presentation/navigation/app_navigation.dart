import 'package:flutter/material.dart';

enum NavTab {
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
}
