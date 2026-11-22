import 'package:flutter/widgets.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';

import '../dialog_tts_screen.dart';
import '../novel_reader_screen.dart';
import '../phase_tts_screen.dart';
import '../song_studio_screen.dart';
import '../subtitle_studio_screen.dart';
import '../video_dub_screen.dart';
import '../voice_asset_screen.dart';

Widget buildWorkspace(
  BuildContext context,
  NavTab tab, {
  required bool active,
  required ValueChanged<Future<bool> Function()?> onPhaseExitGuardChanged,
}) => switch (tab) {
  NavTab.phaseTts => PhaseTtsScreen(
    key: const ValueKey('phaseTts'),
    onExitGuardChanged: onPhaseExitGuardChanged,
  ),
  NavTab.novelReader => const NovelReaderScreen(key: ValueKey('novelReader')),
  NavTab.dialogTts => const DialogTtsScreen(key: ValueKey('dialogTts')),
  NavTab.videoDub => VideoDubScreen(
    key: const ValueKey('videoDub'),
    active: active,
  ),
  NavTab.subtitles => const SubtitleStudioScreen(key: ValueKey('subtitles')),
  NavTab.music => const SongStudioScreen(key: ValueKey('music')),
  NavTab.voiceAssets => const VoiceAssetScreen(key: ValueKey('voiceAssets')),
  _ => throw ArgumentError.value(tab, 'tab'),
};
