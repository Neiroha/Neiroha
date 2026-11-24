// The voice bank screen lists banks, their characters and the inspector.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/screens/voice_bank_screen.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Playback without the native audio engine.
class _Idle extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  testWidgets('shows the active bank, its member and the inspector', (
    tester,
  ) async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.runAsync(() async {
      await database.insertProvider(
        db.TtsProvidersCompanion.insert(
          id: 'p',
          name: 'Local',
          adapterType: 'openaiCompatible',
          baseUrl: 'http://127.0.0.1:9',
        ),
      );
      await database.insertVoiceAsset(
        db.VoiceAssetsCompanion.insert(
          id: 'v',
          name: 'Nagato',
          providerId: 'p',
          taskMode: 'presetVoice',
        ),
      );
      await database.insertBank(
        db.VoiceBanksCompanion.insert(
          id: 'b',
          name: 'Fleet',
          createdAt: DateTime(2026, 11, 24),
        ),
      );
      await database.setActiveBank('b');
      await database.addMemberToBank(
        db.VoiceBankMembersCompanion.insert(
          id: 'm',
          bankId: 'b',
          voiceAssetId: 'v',
        ),
      );
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
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
          home: const Scaffold(body: VoiceBankScreen()),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('Fleet'), findsWidgets);
    await tester.tap(find.text('Fleet').first);
    await settle();
    expect(find.text('Nagato'), findsWidgets);
    await tester.tap(find.text('Nagato').first);
    await settle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
