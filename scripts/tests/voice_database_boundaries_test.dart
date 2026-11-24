// Voice assets, model bindings and their references.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

import 'support/voice_database_fixture.dart';

void main() {
  test('voice asset display names can be duplicated', () async {
    final database = memoryDatabase();
    await insertProvider(database, 'provider-a');

    await database.insertVoiceAsset(
      const db.VoiceAssetsCompanion(
        id: Value('voice-a'),
        name: Value('Generated Name'),
        providerId: Value('provider-a'),
        taskMode: Value('presetVoice'),
      ),
    );
    await database.insertVoiceAsset(
      const db.VoiceAssetsCompanion(
        id: Value('voice-b'),
        name: Value('Generated Name'),
        providerId: Value('provider-a'),
        taskMode: Value('presetVoice'),
      ),
    );

    final matches = (await database.getAllVoiceAssets())
        .where((asset) => asset.name == 'Generated Name')
        .toList();

    expect(
      matches.map((asset) => asset.id),
      containsAll(['voice-a', 'voice-b']),
    );
  });

  test(
    'removing the last bank membership deletes orphan voice references',
    () async {
      final database = memoryDatabase();
      final now = DateTime(2026, 5, 13);
      await insertProvider(database, 'provider-a');
      await database.insertBank(
        db.VoiceBanksCompanion(
          id: const Value('bank-a'),
          name: const Value('Bank A'),
          createdAt: Value(now),
        ),
      );
      await database.insertVoiceAsset(
        const db.VoiceAssetsCompanion(
          id: Value('voice-a'),
          name: Value('Shared Display Name'),
          providerId: Value('provider-a'),
          taskMode: Value('presetVoice'),
        ),
      );
      await database.addMemberToBank(
        const db.VoiceBankMembersCompanion(
          id: Value('member-a'),
          bankId: Value('bank-a'),
          voiceAssetId: Value('voice-a'),
        ),
      );

      await database.insertPhaseTtsProject(
        db.PhaseTtsProjectsCompanion(
          id: const Value('phase-a'),
          name: const Value('Phase'),
          bankId: const Value('bank-a'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.insertPhaseTtsSegment(
        const db.PhaseTtsSegmentsCompanion(
          id: Value('phase-seg-a'),
          projectId: Value('phase-a'),
          orderIndex: Value(0),
          segmentText: Value('hello'),
          voiceAssetId: Value('voice-a'),
        ),
      );

      await database.insertNovelProject(
        db.NovelProjectsCompanion(
          id: const Value('novel-a'),
          name: const Value('Novel'),
          bankId: const Value('bank-a'),
          narratorVoiceAssetId: const Value('voice-a'),
          dialogueVoiceAssetId: const Value('voice-a'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await database.insertDialogTtsProject(
        db.DialogTtsProjectsCompanion(
          id: const Value('dialog-a'),
          name: const Value('Dialog'),
          bankId: const Value('bank-a'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.insertDialogTtsLine(
        const db.DialogTtsLinesCompanion(
          id: Value('dialog-line-a'),
          projectId: Value('dialog-a'),
          orderIndex: Value(0),
          lineText: Value('hello'),
          voiceAssetId: Value('voice-a'),
        ),
      );

      await database.insertVideoDubProject(
        db.VideoDubProjectsCompanion(
          id: const Value('video-a'),
          name: const Value('Video'),
          bankId: const Value('bank-a'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await database.insertSubtitleCue(
        const db.SubtitleCuesCompanion(
          id: Value('cue-a'),
          projectId: Value('video-a'),
          orderIndex: Value(0),
          startMs: Value(0),
          endMs: Value(1000),
          cueText: Value('hello'),
          voiceAssetId: Value('voice-a'),
        ),
      );

      await database.removeMemberByAssetAndBank(
        'bank-a',
        'voice-a',
        deleteOrphanAsset: true,
      );

      expect(await database.getVoiceAssetById('voice-a'), isNull);
      expect(await database.getBankMembers('bank-a'), isEmpty);
      expect(
        (await database.getPhaseTtsSegments('phase-a')).single.voiceAssetId,
        isNull,
      );
      final novel = await database.getNovelProjectById('novel-a');
      expect(novel?.narratorVoiceAssetId, isNull);
      expect(novel?.dialogueVoiceAssetId, isNull);
      expect(
        (await database.getDialogTtsLines('dialog-a')).single.voiceAssetId,
        isNull,
      );
      expect(
        (await database.getSubtitleCues('video-a')).single.voiceAssetId,
        isNull,
      );
    },
  );

  test(
    'deleting a provider removes dependent voices and model bindings',
    () async {
      final database = memoryDatabase();
      final now = DateTime(2026, 5, 13);
      await insertProvider(database, 'provider-a');
      await database.insertBinding(
        const db.ModelBindingsCompanion(
          id: Value('binding-a'),
          providerId: Value('provider-a'),
          modelKey: Value('model-a'),
        ),
      );
      await database.insertBank(
        db.VoiceBanksCompanion(
          id: const Value('bank-a'),
          name: const Value('Bank A'),
          createdAt: Value(now),
        ),
      );
      await database.insertVoiceAsset(
        const db.VoiceAssetsCompanion(
          id: Value('voice-a'),
          name: Value('Provider Voice'),
          providerId: Value('provider-a'),
          taskMode: Value('presetVoice'),
        ),
      );
      await database.addMemberToBank(
        const db.VoiceBankMembersCompanion(
          id: Value('member-a'),
          bankId: Value('bank-a'),
          voiceAssetId: Value('voice-a'),
        ),
      );

      await database.deleteProvider('provider-a');

      expect(
        (await database.getAllProviders()).any((p) => p.id == 'provider-a'),
        isFalse,
      );
      expect(await database.getVoiceAssetById('voice-a'), isNull);
      expect(await database.getBankMembers('bank-a'), isEmpty);
      expect(await database.getBindingsForProvider('provider-a'), isEmpty);
    },
  );

  test('deleting a model binding clears voice asset references', () async {
    final database = memoryDatabase();
    await insertProvider(database, 'provider-a');
    await database.insertBinding(
      const db.ModelBindingsCompanion(
        id: Value('binding-a'),
        providerId: Value('provider-a'),
        modelKey: Value('model-a'),
      ),
    );
    await database.insertVoiceAsset(
      const db.VoiceAssetsCompanion(
        id: Value('voice-a'),
        name: Value('Bound Voice'),
        providerId: Value('provider-a'),
        modelBindingId: Value('binding-a'),
        taskMode: Value('presetVoice'),
      ),
    );

    await database.deleteBinding('binding-a');

    expect(
      (await database.getVoiceAssetById('voice-a'))?.modelBindingId,
      isNull,
    );
    expect(await database.getBindingsForProvider('provider-a'), isEmpty);
  });

  test(
    'voice bank deletion is blocked while projects still reference it',
    () async {
      final database = memoryDatabase();
      final now = DateTime(2026, 5, 13);
      await database.insertBank(
        db.VoiceBanksCompanion(
          id: const Value('bank-a'),
          name: const Value('Bank A'),
          createdAt: Value(now),
        ),
      );
      await database.insertPhaseTtsProject(
        db.PhaseTtsProjectsCompanion(
          id: const Value('phase-a'),
          name: const Value('Phase'),
          bankId: const Value('bank-a'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await expectLater(
        database.deleteBank('bank-a'),
        throwsA(isA<StateError>()),
      );

      expect(
        (await database.getAllBanks()).map((bank) => bank.id),
        contains('bank-a'),
      );
      expect(await database.getPhaseTtsProjectById('phase-a'), isNotNull);
    },
  );
}
