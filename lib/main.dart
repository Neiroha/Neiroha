import 'dart:async';

import 'dart:ui' show AppExitResponse;
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'data/database/app_database.dart'
    show AppDatabaseAiQueries, AppDatabaseStorageQueries;
import 'data/storage/path_service.dart';
import 'l10n/app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/screens/app_shell.dart';
import 'presentation/theme/app_font.dart';
import 'presentation/theme/app_theme.dart';
import 'data/services/transcription/media_pcm_decoder.dart';
import 'providers/ai_capability_providers.dart';
import 'providers/app_providers.dart';
import 'server/api_server.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const ProviderScope(child: NeirohaApp()));
    return;
  }

  // libmpv init for Video Dub's mp4 playback. Cheap to call up-front; no video
  // is loaded until the user enters Video Dub.
  MediaKit.ensureInitialized();

  // Resolve data/ and voice_asset/ before any DB or file access so the very
  // first DB open lands in the right place (portable EXE dir when writable,
  // OS app-support dir otherwise).
  await PathService.instance.init();

  // Page headers drag the window through window_manager; on macOS it must
  // be initialized too, or startDragging dereferences a nil window.
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
  }
  if (Platform.isWindows) {
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
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<Object?> _capabilityLimits;
  Future<void>? _webSettings;
  @override
  void initState() {
    super.initState();
    // Every app synthesis path runs the character's processing chain.
    // Desktop decodes encoded engines with FFmpeg so they stream by sentence.
    final decoder = kIsWeb
        ? null
        : MediaPcmDecoder(ref.read(ffmpegServiceProvider));
    ref.read(ttsQueueServiceProvider).voiceChains = VoiceChainHook(
      ref.read(databaseProvider),
      decode: decoder == null
          ? null
          : (bytes, format) =>
                decodeSpeechBytes(decoder, bytes, format.extension),
    ).wrap;
    // Queue lanes follow the per-capability limits as they are edited.
    _capabilityLimits = ref
        .read(databaseProvider)
        .watchConnectionCapabilities()
        .listen(ref.read(ttsQueueServiceProvider).setCapabilityLimits);
    // Public model facts (models.dev): cached copy now, refresh daily.
    unawaited(startModelCatalogRefresh(ref));
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        if (kIsWeb) return AppExitResponse.exit;
        ref.read(roleAnalysisServiceProvider).dispose();
        ref.read(roleReviewServiceProvider).dispose();
        // Each step is bounded: a step that fails or hangs must not keep
        // the app from quitting. Timings go to logs/last_exit.log, written
        // before and after every step so a crash shows where it happened.
        final log = <String>['started'];
        _writeExitLog(log);
        await _exitStep(
          'playback',
          ref.read(playbackNotifierProvider.notifier).stop,
          log,
        );
        await _exitStep('api server', ref.read(apiServerProvider).stop, log);
        await _exitStep('capability limits', _capabilityLimits.cancel, log);
        // Close SQLite before the engine ends the process: left open, its
        // finalizer can run while the process tears down and crash in
        // sqlite3Close.
        await _exitStep(
          'database',
          ref.read(databaseProvider).closeConnection,
          log,
          timeout: const Duration(seconds: 5),
        );
        _writeExitLog(log..add('done'));
        return AppExitResponse.exit;
      },
    );
    if (kIsWeb) {
      _webSettings = Future.microtask(_loadAppSettings);
    } else {
      Future.microtask(_loadAppSettings);
      Future.microtask(_autoStartApiServer);
    }
  }

  static Future<void> _exitStep(
    String name,
    Future<void> Function() step,
    List<String> log, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final watch = Stopwatch()..start();
    log.add('$name: running');
    _writeExitLog(log);
    log.removeLast();
    var outcome = 'ok';
    try {
      await step().timeout(timeout);
    } on TimeoutException {
      outcome = 'timed out';
    } catch (error) {
      outcome = 'failed: $error';
    }
    log.add('$name: ${watch.elapsedMilliseconds} ms, $outcome');
    _writeExitLog(log);
  }

  /// Records how the last quit went, to trace a step that hangs.
  static void _writeExitLog(List<String> log) {
    try {
      final file = File(
        '${PathService.instance.dataRoot.path}/logs/last_exit.log',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()}\n${log.join('\n')}\n',
      );
    } catch (_) {
      // Logging must never block quitting.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_capabilityLimits.cancel());
    super.dispose();
  }

  /// Honour Settings → API Server → "Start on launch" so agents can reach
  /// the local API / MCP endpoint without a manual toggle.
  Future<void> _autoStartApiServer() async {
    final db = ref.read(databaseProvider);
    final config = await ApiServerConfig.load(db);
    if (!config.autoStart) return;
    try {
      await ref.read(apiServerProvider).start(config: config);
      if (!mounted) return;
      ref.read(serverRunningProvider.notifier).state = true;
    } catch (e) {
      // e.g. the port is already taken; the user can still start it manually.
      debugPrint('API server auto-start failed: $e');
    }
  }

  Future<void> _loadAppSettings() async {
    final db = ref.read(databaseProvider);
    final storedLocale = await db.getSetting(AppLocaleSettings.localeKey);
    final storedFont = await db.getSetting(AppFontSettings.fontModeKey);
    final locale = AppLocaleSettings.parse(storedLocale);
    await db.localizeStarterContent(AppLocaleSettings.storageValue(locale));
    if (!mounted) return;
    ref.read(appLocaleProvider.notifier).state = locale;
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
      home: kIsWeb
          ? FutureBuilder<void>(
              future: _webSettings,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppLocalizations.of(context).webStorageUnavailable,
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.done) {
                  return const AppShell();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            )
          : const AppShell(),
    );
  }
}
