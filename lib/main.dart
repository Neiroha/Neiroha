import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'data/database/app_database.dart' show AppDatabaseStorageQueries;
import 'data/storage/path_service.dart';
import 'l10n/app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/theme/app_font.dart';
import 'presentation/theme/app_theme.dart';
import 'providers/app_providers.dart';

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

class NeirohaApp extends ConsumerStatefulWidget {
  const NeirohaApp({super.key});

  @override
  ConsumerState<NeirohaApp> createState() => _NeirohaAppState();
}

class _NeirohaAppState extends ConsumerState<NeirohaApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAppSettings);
  }

  Future<void> _loadAppSettings() async {
    final db = ref.read(databaseProvider);
    final storedLocale = await db.getSetting(AppLocaleSettings.localeKey);
    final storedFont = await db.getSetting(AppFontSettings.fontModeKey);
    if (!mounted) return;
    ref.read(appLocaleProvider.notifier).state = AppLocaleSettings.parse(
      storedLocale,
    );
    ref.read(appFontModeProvider.notifier).state = AppFontMode.parse(
      storedFont,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider);
    final fontMode = ref.watch(appFontModeProvider);
    return MaterialApp(
      title: 'Neiroha',
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(fontMode: fontMode),
      locale: locale,
      supportedLocales: AppLocaleSettings.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
