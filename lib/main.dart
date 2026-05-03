import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'data/storage/path_service.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // libmpv init for Video Dub's mp4 playback. Cheap to call up-front; no video
  // is loaded until the user enters Video Dub.
  MediaKit.ensureInitialized();

  // Resolve data/ and voice_asset/ before any DB or file access so the very
  // first DB open lands in the right place (portable EXE dir when writable,
  // OS app-support dir otherwise).
  await PathService.instance.init();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: 'Neiroha',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: NeirohaApp()));
}

class NeirohaApp extends StatelessWidget {
  const NeirohaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neiroha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
