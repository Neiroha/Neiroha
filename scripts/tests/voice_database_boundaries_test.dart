import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

void main() {
  db.AppDatabase memoryDatabase() {
    final database = db.AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    return database;
  }

  Future<void> insertProvider(db.AppDatabase database, String providerId) {
    return database.insertProvider(
      db.TtsProvidersCompanion(
        id: Value(providerId),
        name: Value(providerId),
        adapterType: const Value('openaiCompatible'),
        baseUrl: const Value('http://localhost'),
      ),
    );
  }

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

  test('adding the same voice to a bank is idempotent', () async {
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
        name: Value('Voice A'),
        providerId: Value('provider-a'),
        taskMode: Value('presetVoice'),
      ),
    );

    final first = await database.addMemberToBank(
      const db.VoiceBankMembersCompanion(
        id: Value('member-a'),
        bankId: Value('bank-a'),
        voiceAssetId: Value('voice-a'),
      ),
    );
    final second = await database.addMemberToBank(
      const db.VoiceBankMembersCompanion(
        id: Value('member-b'),
        bankId: Value('bank-a'),
        voiceAssetId: Value('voice-a'),
      ),
    );

    expect(first, greaterThan(0));
    expect(second, 0);
    expect(await database.getBankMembers('bank-a'), hasLength(1));
  });

  test('project and source deletion keeps timeline clips in bounds', () async {
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
    await database.insertPhaseTtsSegment(
      const db.PhaseTtsSegmentsCompanion(
        id: Value('phase-seg-a'),
        projectId: Value('phase-a'),
        orderIndex: Value(0),
        segmentText: Value('phase line'),
      ),
    );
    await database.insertTimelineClip(
      const db.TimelineClipsCompanion(
        id: Value('phase-clip-a'),
        projectId: Value('phase-a'),
        projectType: Value('phase'),
        audioPath: Value('phase.wav'),
        sourceLineId: Value('phase-seg-a'),
      ),
    );

    await database.deletePhaseTtsSegment('phase-seg-a');

    expect(await database.getTimelineClips('phase-a', 'phase'), isEmpty);

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
        lineText: Value('dialog line'),
      ),
    );
    await database.insertTimelineClip(
      const db.TimelineClipsCompanion(
        id: Value('dialog-clip-a'),
        projectId: Value('dialog-a'),
        projectType: Value('dialog'),
        audioPath: Value('dialog.wav'),
        sourceLineId: Value('dialog-line-a'),
      ),
    );

    await database.deleteDialogTtsProject('dialog-a');

    expect(await database.getTimelineClips('dialog-a', 'dialog'), isEmpty);
    expect(await database.getDialogTtsProjectById('dialog-a'), isNull);

    await database.insertVideoDubProject(
      db.VideoDubProjectsCompanion(
        id: const Value('video-a'),
        name: const Value('Video'),
        bankId: const Value('bank-a'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await database.insertTimelineClip(
      const db.TimelineClipsCompanion(
        id: Value('video-clip-a'),
        projectId: Value('video-a'),
        projectType: Value('videodub'),
        audioPath: Value('video.mp4'),
        sourceType: Value('video'),
        linkGroupId: Value('link-a'),
      ),
    );
    await database.insertTimelineClip(
      const db.TimelineClipsCompanion(
        id: Value('video-audio-clip-a'),
        projectId: Value('video-a'),
        projectType: Value('videodub'),
        laneIndex: Value(1),
        audioPath: Value('video.mp4'),
        sourceType: Value('video-audio'),
        linkGroupId: Value('link-a'),
      ),
    );

    await database.deleteTimelineClip('video-clip-a');

    expect(await database.getTimelineClips('video-a', 'videodub'), isEmpty);
  });

  test(
    'audio archive cleanup covers subtitle and reference audio columns',
    () async {
      final database = memoryDatabase();
      final now = DateTime(2026, 5, 13);
      const audioPath = r'D:\audio\sample.wav';
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
          name: Value('Ref Voice'),
          providerId: Value('provider-a'),
          taskMode: Value('cloneWithPrompt'),
          refAudioPath: Value(audioPath),
          refAudioTrimStart: Value(0.2),
          refAudioTrimEnd: Value(1.2),
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
          audioPath: Value(audioPath),
          audioDuration: Value(1),
          error: Value('old error'),
          missing: Value(true),
        ),
      );

      await database.clearAllAudioArchives();

      final voice = await database.getVoiceAssetById('voice-a');
      expect(voice?.refAudioPath, isNull);
      expect(voice?.refAudioTrimStart, isNull);
      expect(voice?.refAudioTrimEnd, isNull);
      final cue = (await database.getSubtitleCues('video-a')).single;
      expect(cue.audioPath, isNull);
      expect(cue.audioDuration, isNull);
      expect(cue.error, isNull);
      expect(cue.missing, isFalse);
    },
  );

  test(
    'deleting an audio track clears and marks rows using its path',
    () async {
      final database = memoryDatabase();
      final now = DateTime(2026, 5, 13);
      const audioPath = r'D:\audio\sample.wav';
      await insertProvider(database, 'provider-a');
      await database.insertBank(
        db.VoiceBanksCompanion(
          id: const Value('bank-a'),
          name: const Value('Bank A'),
          createdAt: Value(now),
        ),
      );
      await database.insertAudioTrack(
        db.AudioTracksCompanion(
          id: const Value('track-a'),
          name: const Value('Track A'),
          audioPath: const Value(audioPath),
          createdAt: Value(now),
        ),
      );
      await database.insertVoiceAsset(
        const db.VoiceAssetsCompanion(
          id: Value('voice-a'),
          name: Value('Ref Voice'),
          providerId: Value('provider-a'),
          taskMode: Value('cloneWithPrompt'),
          refAudioPath: Value(audioPath),
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
          audioPath: Value(audioPath),
        ),
      );
      await database.insertTimelineClip(
        const db.TimelineClipsCompanion(
          id: Value('clip-a'),
          projectId: Value('video-a'),
          projectType: Value('videodub'),
          audioPath: Value(audioPath),
        ),
      );

      await database.deleteAudioTrack('track-a');

      expect(await database.getAllAudioTracksRaw(), isEmpty);
      expect(
        (await database.getVoiceAssetById('voice-a'))?.refAudioPath,
        isNull,
      );
      expect(
        (await database.getSubtitleCues('video-a')).single.missing,
        isTrue,
      );
      expect(
        (await database.getTimelineClips('video-a', 'videodub')).single.missing,
        isTrue,
      );
    },
  );
}
