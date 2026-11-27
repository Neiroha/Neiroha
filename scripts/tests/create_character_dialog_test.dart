// The create-character dialog builds the fields of every adapter branch.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/presentation/widgets/voice_character/create_character_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';

db.TtsProvider _provider(AdapterType type) => db.TtsProvider(
  id: type.name,
  name: type.displayName,
  adapterType: type.name,
  baseUrl: 'http://127.0.0.1:9',
  apiKey: 'fixture',
  defaultModelName: type.defaultModel,
  enabled: true,
  position: 0,
  maxConcurrency: 1,
);

void main() {
  for (final type in [
    AdapterType.openaiTts,
    AdapterType.elevenLabs,
    AdapterType.cosyvoice,
    AdapterType.voxcpm2Native,
    AdapterType.gptSovits,
    AdapterType.indexTts,
    AdapterType.rvc,
  ]) {
    testWidgets('builds the ${type.name} fields', (tester) async {
      final database = db.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      // The test font draws every glyph as a full square, so long labels
      // overflow rows that fit with real fonts; only other errors count.
      final errors = <FlutterErrorDetails>[];
      final reportError = FlutterError.onError;
      FlutterError.onError = (e) {
        if (!e.toString().contains('overflowed')) errors.add(e);
      };
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CreateCharacterDialog(
                providers: [_provider(type)],
                database: database,
                onSave: (_) async {},
                onSaveAudioTrack: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsWidgets);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pump();
      // Local engines fetch voices on open; let those requests fail out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
      FlutterError.onError = reportError;
      expect([for (final e in errors) e.exceptionAsString()], isEmpty);
    });
  }

  testWidgets('a preset voice character starts on a voice the model offers', (
    tester,
  ) async {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = _provider(AdapterType.openaiTts);
    await tester.runAsync(() async {
      await database.insertProvider(provider.toCompanion(false));
      for (final (key, modes) in [
        ('gpt-realtime-2.1', ''),
        ('fable', 'voice'),
      ]) {
        await database.insertBinding(
          db.ModelBindingsCompanion.insert(
            id: key,
            providerId: provider.id,
            modelKey: key,
            supportedTaskModes: Value(modes),
          ),
        );
      }
    });
    final saved = <db.VoiceAssetsCompanion>[];
    final reportError = FlutterError.onError;
    // The test font overflows rows that fit with real fonts.
    FlutterError.onError = (e) {
      if (!e.toString().contains('overflowed')) reportError?.call(e);
    };
    addTearDown(() => FlutterError.onError = reportError);
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CreateCharacterDialog(
              providers: [provider],
              database: database,
              onSave: (c) async => saved.add(c),
              onSaveAudioTrack: (_) async {},
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    TextField voiceField() => tester.widget<TextField>(
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '音色 / 说话人 ID',
      ),
    );
    // The only model is chosen, and with it its first voice.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      endsWith('_marin'),
    );
    await tester.scrollUntilVisible(
      find.text('音色 / 说话人 ID'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(voiceField().controller!.text, 'marin');
    // A speech-only voice is not offered for a Realtime model.
    final voices = tester
        .widget<VoiceCharacterVoiceSearchPicker>(
          find.byWidgetPredicate(
            (w) => w is VoiceCharacterVoiceSearchPicker && w.label == '选择音色',
          ),
        )
        .voices;
    expect(voices, contains('marin'));
    expect(voices, isNot(contains('fable')));

    voiceField().controller!.clear();
    await tester.ensureVisible(find.text('创建角色'));
    await tester.tap(find.text('创建角色'));
    await tester.pump();
    expect(find.text('请选择音色'), findsOneWidget);
    expect(saved, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
