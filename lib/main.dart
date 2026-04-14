import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
