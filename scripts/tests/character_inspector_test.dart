// The character inspector builds its Voice tab for each kind of adapter.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/voice_character/character_inspector.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Playback without the native audio engine.
class _Idle extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  for (final (adapter, mode) in [
    ('openaiTts', 'presetVoice'),
    ('gptSovits', 'cloneWithPrompt'),
    ('cosyvoice', 'cloneWithPrompt'),
    ('indexTts', 'cloneWithPrompt'),
  ]) {
    testWidgets('builds the Voice tab for $adapter', (tester) async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final asset = await tester.runAsync(() async {
        await database.insertProvider(
          db.TtsProvidersCompanion.insert(
            id: 'p',
            name: adapter,
            adapterType: adapter,
            baseUrl: 'http://127.0.0.1:9',
          ),
        );
        await database.insertVoiceAsset(
          db.VoiceAssetsCompanion.insert(
            id: 'v',
            name: 'Nagato',
            providerId: 'p',
            taskMode: mode,
          ),
        );
        return database.getVoiceAssetById('v');
      });
      final errors = <String>[];
      final reportError = FlutterError.onError;
      // The test font draws every glyph as a full square, so long labels
      // overflow rows that fit with real fonts; only other errors count.
      FlutterError.onError = (e) {
        if (!e.toString().contains('overflowed')) {
          errors.add(e.exceptionAsString());
        }
      };
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            playbackNotifierProvider.overrideWith(_Idle.new),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: CharacterInspector(asset: asset!)),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
      }

      await settle();
      await tester.tap(find.byIcon(Icons.record_voice_over_rounded));
      await settle();
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
      FlutterError.onError = reportError;
      expect(errors, isEmpty);
    });
  }

  testWidgets('a voice the model lacks is flagged; a picked voice saves', (
    tester,
  ) async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final asset = await tester.runAsync(() async {
      await database.insertProvider(
        db.TtsProvidersCompanion.insert(
          id: 'p',
          name: 'OpenAI',
          adapterType: 'openaiTts',
          baseUrl: 'http://127.0.0.1:9',
        ),
      );
      await database.insertVoiceAsset(
        db.VoiceAssetsCompanion.insert(
          id: 'v',
          name: 'Nagato',
          providerId: 'p',
          taskMode: 'presetVoice',
          modelName: const Value('gpt-realtime-2.1'),
          presetVoiceName: const Value('fable'),
        ),
      );
      return database.getVoiceAssetById('v');
    });
    final reportError = FlutterError.onError;
    // The test font overflows rows that fit with real fonts.
    FlutterError.onError = (e) {
      if (!e.toString().contains('overflowed')) reportError?.call(e);
    };
    addTearDown(() => FlutterError.onError = reportError);
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          playbackNotifierProvider.overrideWith(_Idle.new),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CharacterInspector(asset: asset!)),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await settle();
    await tester.tap(find.byIcon(Icons.record_voice_over_rounded));
    await settle();
    expect(find.text('gpt-realtime-2.1 不支持音色 fable，请重新选择'), findsOneWidget);

    await tester.tap(find.textContaining('available'));
    await tester.pump();
    await tester.tap(find.text('cedar'));
    await settle();
    // No save needed: the quick test reads the saved voice.
    final saved = await tester.runAsync(() => database.getVoiceAssetById('v'));
    expect(saved!.presetVoiceName, 'cedar');
    await tester.pump(const Duration(milliseconds: 300)); // error fades out
    expect(find.textContaining('不支持音色'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
