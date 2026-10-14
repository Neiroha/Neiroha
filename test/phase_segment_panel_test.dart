import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/phase_tts/segment_voice_panel.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

class _FakeStorage extends StorageService {
  _FakeStorage(super.db);

  @override
  Future<String> ensurePhaseProjectSlug(String projectId) async => 'test';
}

class _FakeSettingsFile extends PhaseSegmentSettingsFileService {
  @override
  Future<PhaseSegmentSettings> load(String projectSlug) async =>
      const PhaseSegmentSettings();

  @override
  Future<void> save(String projectSlug, PhaseSegmentSettings settings) async {}
}

class _SilentPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState();
}

void main() {
  final now = DateTime(2026);
  final project = db.PhaseTtsProject(
    id: 'p1',
    name: 'ASMR',
    bankId: 'b1',
    scriptText: '',
    createdAt: now,
    updatedAt: now,
  );
  final voice = db.VoiceAsset(
    id: 'v1',
    name: 'A rather long voice name for wrapping',
    providerId: 'prov',
    taskMode: 'presetVoice',
    speed: 1,
    enabled: true,
  );
  db.PhaseTtsSegment seg(
    int i, {
    String? voice,
    String? audio,
    String? error,
  }) => db.PhaseTtsSegment(
    id: 's$i',
    projectId: 'p1',
    orderIndex: i,
    segmentText: '第 $i 句。' * (i + 1),
    voiceAssetId: voice,
    audioPath: audio,
    audioDuration: audio == null ? null : 3.2,
    error: error,
    missing: false,
  );
  final segments = [
    seg(0, voice: 'v1', audio: 'a.wav'),
    seg(1, voice: 'v1', error: 'HTTP 500'),
    seg(2),
  ];

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          storageServiceProvider.overrideWithValue(_FakeStorage(database)),
          phaseSegmentSettingsFileServiceProvider.overrideWithValue(
            _FakeSettingsFile(),
          ),
          playbackNotifierProvider.overrideWith(_SilentPlayback.new),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SegmentVoicePanel(
              project: project,
              segments: segments,
              bankAssets: [voice],
              generatingSegmentIds: const {},
              onApplyVoiceToAll: (_) async {},
              onVoiceChanged: (_, _) {},
              onPlay: (_, _) {},
              onGenerate: (_) async {},
              onDelete: (_) {},
              onEditText: (_, _) async {},
              onChanged: () {},
              onPlayAll: () {},
              onGenerateAll: () {},
              onNormalize: () {},
              generatingAll: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(340, 720), Size(1100, 800)]) {
    testWidgets('lays out without overflow at ${size.width.toInt()}px', (
      tester,
    ) async {
      await pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('已生成 1/3'), findsOneWidget);
      expect(find.text('失败 1'), findsWidgets);
      expect(find.text('统一音量'), findsOneWidget);
    });
  }

  testWidgets('status filter narrows the list', (tester) async {
    await pump(tester, const Size(900, 800));
    expect(find.text('HTTP 500'), findsOneWidget);
    await tester.tap(find.text('已生成 1'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP 500'), findsNothing);
    expect(find.text('第 0 句。'), findsOneWidget);
  });
}
