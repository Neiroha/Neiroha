// The voice bank screen: the bank switcher over its cast, the quick test
// and the inspector.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/screens/voice_bank_screen.dart';
import 'package:neiroha/presentation/widgets/quick_tts_panel.dart';
import 'package:neiroha/presentation/widgets/voice_character/character_inspector.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Playback without the native audio engine.
class _Idle extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  Future<db.AppDatabase> seed(WidgetTester tester) async {
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
      for (final (id, name) in [('a', 'Archive'), ('b', 'Fleet')]) {
        await database.insertBank(
          db.VoiceBanksCompanion.insert(
            id: id,
            name: name,
            createdAt: DateTime(2026, 11, 24),
          ),
        );
      }
      await database.setActiveBank('b');
      await database.addMemberToBank(
        db.VoiceBankMembersCompanion.insert(
          id: 'm',
          bankId: 'b',
          voiceAssetId: 'v',
        ),
      );
    });
    return database;
  }

  Future<void> pump(
    WidgetTester tester,
    db.AppDatabase database,
    Size size,
  ) async {
    await tester.binding.setSurfaceSize(size);
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
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('wide: the active bank opens, quick test beside the inspector', (
    tester,
  ) async {
    final database = await seed(tester);
    await pump(tester, database, const Size(1600, 900));
    await settle(tester);
    // The active bank is chosen without a click; its cast shows at once.
    expect(find.text('Fleet'), findsOneWidget);
    expect(find.text('Nagato'), findsOneWidget);
    await tester.tap(find.text('Nagato'));
    await settle(tester);
    final quick = tester.getRect(find.byType(QuickTtsPanel));
    final inspector = tester.getRect(find.byType(CharacterInspector));
    // Three columns: the quick test is the widest, the inspector at right.
    expect(quick.right, lessThanOrEqualTo(inspector.left));
    expect(quick.width, greaterThan(inspector.width));
    expect(inspector.width, 420);

    // The switcher lists every bank and switches to another.
    await tester.tap(find.text('Fleet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await settle(tester);
    expect(find.text('Nagato'), findsNothing);
    expect(find.byType(QuickTtsPanel), findsNothing);
    expect(tester.takeException(), isNull);
    await tearDownScreen(tester);
  });

  testWidgets('narrower: the quick test stacks over the inspector', (
    tester,
  ) async {
    final database = await seed(tester);
    await pump(tester, database, const Size(1000, 900));
    await settle(tester);
    await tester.tap(find.text('Nagato'));
    await settle(tester);
    final quick = tester.getRect(find.byType(QuickTtsPanel));
    final inspector = tester.getRect(find.byType(CharacterInspector));
    expect(quick.bottom, lessThanOrEqualTo(inspector.top));
    expect(tester.takeException(), isNull);
    await tearDownScreen(tester);
  });
}
