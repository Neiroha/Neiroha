import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_audio_fingerprint.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/novel_voice_resolution.dart';
import 'package:neiroha/domain/novel/role_models.dart';

import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late AnnotationRepository annotations;
  late List<db.NovelSegment> segments;
  late String character;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    characters = CharacterRepository(database);
    annotations = AnnotationRepository(database);
    await seedNovelFixture(database);
    segments = await database.getNovelSegments('book');
    character = await characters.saveCharacter(
      projectId: 'book',
      name: '林舟',
      aliases: ['小林'],
    );
  });
  tearDown(() => database.close());

  SegmentAnnotation patch(
    int i, {
    bool locked = false,
    String? revision,
    String? characterId,
  }) => SegmentAnnotation(
    segmentId: segments[i].id,
    projectId: 'book',
    textRevision: revision ?? novelTextRevision(segments[i].segmentText),
    characterId: characterId ?? character,
    kind: NovelSegmentKind.dialogue,
    locked: locked,
  );

  test(
    'manual lock persists and AI cannot mark itself manually confirmed',
    () async {
      await annotations.apply('book', [patch(0, locked: true)]);
      expect(
        await annotations.apply('book', [patch(0), patch(1)], fromAi: true),
        1,
      );
      final snapshot = await characters.load('book');
      expect(snapshot.annotations[segments[0].id]!.locked, isTrue);
      expect(
        snapshot.annotations[segments[0].id]!.reviewState,
        NovelReviewState.confirmed,
      );
      expect(
        snapshot.annotations[segments[1].id]!.reviewState,
        NovelReviewState.pending,
      );
      expect(
        (await database.getNovelSegments('book'))[0].segmentText,
        '“你好，𠮷野🌸。”',
      );
    },
  );

  test('revision mismatch rolls the entire batch back', () async {
    await expectLater(
      annotations.apply('book', [patch(0), patch(1, revision: 'old')]),
      throwsStateError,
    );
    expect((await characters.load('book')).annotations, isEmpty);
  });

  test('cross-work characters and voices are rejected', () async {
    final other = await characters.saveCharacter(
      projectId: 'other-book',
      name: '他人',
    );
    await expectLater(
      annotations.apply('book', [patch(0, characterId: other)]),
      throwsArgumentError,
    );
    await expectLater(
      characters.bindVoice(
        projectId: 'book',
        characterId: other,
        voiceAssetId: 'voice-a',
      ),
      throwsArgumentError,
    );
    await expectLater(
      characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'missing',
      ),
      throwsArgumentError,
    );
  });

  test(
    'durable range undo restores both annotations, including lock state',
    () async {
      await annotations.apply('book', [patch(0, locked: true)]);
      await annotations.apply('book', [patch(0), patch(1)]);
      expect(await annotations.undo('book'), isTrue);
      final snapshot = await characters.load('book');
      expect(snapshot.annotations.length, 1);
      expect(snapshot.annotations[segments[0].id]!.locked, isTrue);
      expect(await annotations.undo('book'), isTrue);
      expect((await characters.load('book')).annotations, isEmpty);
    },
  );

  test('undo refuses to overwrite a later external patch', () async {
    await annotations.apply('book', [patch(0)]);
    await database.customStatement(
      'UPDATE novel_annotations SET change_id = ? WHERE segment_id = ?',
      ['external-change', segments[0].id],
    );
    await expectLater(annotations.undo('book'), throwsStateError);
  });

  test('AI preserves manual confirmation even without a lock', () async {
    await annotations.apply('book', [patch(0)]);
    expect(await annotations.apply('book', [patch(0)], fromAi: true), 0);
    expect(await annotations.undo('book'), isTrue);
  });

  test(
    'voice resolution: sentence, chapter, work, category, fallback',
    () async {
      await annotations.apply('book', [patch(0)]);
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-a',
      );
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-b',
        chapterId: 'book-chapter',
      );
      final project = (await database.getNovelProjectById('book'))!;
      var roles = await characters.load('book');
      expect(
        resolveNovelSegmentVoice(
          project: project,
          segment: segments[0],
          roles: roles,
          availableVoiceIds: ['voice-a', 'voice-b'],
        ).voiceAssetId,
        'voice-b',
      );
      await annotations.apply('book', [
        SegmentAnnotation(
          segmentId: segments[0].id,
          projectId: 'book',
          textRevision: novelTextRevision(segments[0].segmentText),
          characterId: character,
          kind: NovelSegmentKind.dialogue,
          voiceAssetId: 'voice-a',
          instruction: '轻声',
        ),
      ]);
      roles = await characters.load('book');
      final resolved = resolveNovelSegmentVoice(
        project: project,
        segment: segments[0],
        roles: roles,
        availableVoiceIds: ['voice-a', 'voice-b'],
      );
      expect(resolved.voiceAssetId, 'voice-a');
      expect(resolved.instruction, '轻声');
      expect(
        resolveNovelSegmentVoice(
          project: project,
          segment: segments[0],
          roles: roles,
          availableVoiceIds: ['voice-b'],
        ).voiceAssetId,
        'voice-b',
      );
      expect(
        resolveNovelSegmentVoice(
          project: project,
          segment: segments[0].copyWith(segmentText: 'changed'),
          roles: roles,
          availableVoiceIds: ['voice-a', 'voice-b'],
        ).voiceAssetId,
        'voice-b',
      );
    },
  );

  test('merge preserves aliases and locks, purges source binding', () async {
    await annotations.apply('book', [patch(0, locked: true)]);
    await characters.bindVoice(
      projectId: 'book',
      characterId: character,
      voiceAssetId: 'voice-a',
    );
    final target = await characters.saveCharacter(
      projectId: 'book',
      name: '林先生',
    );
    await characters.merge('book', character, target);
    final roles = await characters.load('book');
    expect(roles.characters.single.aliases, containsAll(['林舟', '小林']));
    expect(roles.annotations[segments[0].id]!.characterId, target);
    expect(roles.annotations[segments[0].id]!.locked, isTrue);
    expect(roles.bindings, isEmpty);
  });

  test(
    'display names preserve cache, synthesis inputs change fingerprint',
    () async {
      final project = (await database.getNovelProjectById('book'))!;
      final asset = (await database.getVoiceAssetById('voice-a'))!;
      final provider = (await database.getAllProviders()).firstWhere(
        (p) => p.id == 'test-provider',
      );
      String key(db.VoiceAsset v, [String? instruction]) =>
          NovelAudioFingerprint.build(
            project: project,
            segment: segments[0],
            asset: v,
            provider: provider,
            instruction: instruction,
          );
      final original = key(asset);
      expect(key(asset.copyWith(name: '显示新名字')), original);
      expect(key(asset.copyWith(speed: 1.2)), isNot(original));
      expect(key(asset, '轻声'), isNot(original));
      expect(
        key(asset.copyWith(presetVoiceName: const Value('other'))),
        isNot(original),
      );
      final reference = await Directory.systemTemp.createTemp('novel_ref_');
      addTearDown(() => reference.delete(recursive: true));
      final file = File('${reference.path}/ref.wav');
      await file.writeAsBytes([1, 2]);
      final withRef = asset.copyWith(refAudioPath: Value(file.path));
      final before = key(withRef);
      await file.writeAsBytes([1, 2, 3]);
      expect(key(withRef), isNot(before));
    },
  );

  test(
    'chapter deletion clears annotations and chapter-specific bindings',
    () async {
      await annotations.apply('book', [patch(0)]);
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-a',
        chapterId: 'book-chapter',
      );
      await database.deleteNovelChapter('book', 'book-chapter');
      final roles = await characters.load('book');
      expect(roles.annotations, isEmpty);
      expect(roles.bindings, isEmpty);
      expect(roles.characters, hasLength(1));
      await database.deleteNovelProject('book');
      expect((await characters.load('book')).characters, isEmpty);
    },
  );
}
