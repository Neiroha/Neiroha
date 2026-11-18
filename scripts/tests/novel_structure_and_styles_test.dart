import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/character_split_service.dart';
import 'package:neiroha/data/services/novel/novel_structure_editor.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_preferences.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/voice_resolver.dart';

import 'support/novel_fixture.dart';

void main() {
  late db.AppDatabase database;
  late CharacterRepository characters;
  late NovelStructureEditor editor;
  late String character;
  late List<db.NovelSegment> segments;
  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    await seedNovelFixture(database);
    characters = CharacterRepository(database);
    editor = NovelStructureEditor(database);
    character = await characters.saveCharacter(
      projectId: 'book',
      name: '路人甲',
      identityKind: CharacterIdentityKind.anonymous,
    );
    segments = await database.getNovelSegments('book');
    await AnnotationRepository(database).apply('book', [
      for (final s in segments)
        SegmentAnnotation(
          segmentId: s.id,
          projectId: 'book',
          textRevision: novelTextRevision(s.segmentText),
          characterId: character,
          kind: NovelSegmentKind.dialogue,
          locked: true,
        ),
    ]);
  });
  tearDown(() => database.close());

  test(
    'split isolates UTF-16 range without dropping text, remaps labels and undoes',
    () async {
      final source = segments.first;
      final start = source.segmentText.indexOf('𠮷');
      final result = await editor.split(source, start, start + 2);
      expect(result.map((s) => s.segmentText).join(), source.segmentText);
      expect(result[1].segmentText, '𠮷');
      expect(result.first.id, source.id);
      final roles = await characters.load('book');
      for (final s in result) {
        expect(roles.annotations[s.id]!.characterId, character);
        expect(roles.annotations[s.id]!.locked, isTrue);
        expect(
          roles.annotations[s.id]!.textRevision,
          novelTextRevision(s.segmentText),
        );
        expect(s.audioCacheKey, isNull);
      }
      final all = await database.getNovelSegments('book');
      expect(all.map((s) => s.globalIndex), List.generate(5, (i) => i));
      expect(await NovelStructureEditor(database).undo('book'), isTrue);
      expect(await database.getNovelSegments('book'), segments);
    },
  );

  test(
    'invalid surrogate boundary, stale source and non-adjacent merge are atomic',
    () async {
      final source = segments.first;
      final offset = source.segmentText.indexOf('𠮷');
      await expectLater(
        editor.split(source, offset + 1, offset + 1),
        throwsArgumentError,
      );
      await expectLater(
        editor.merge([segments[0], segments[2]]),
        throwsArgumentError,
      );
      await expectLater(
        editor.split(source.copyWith(segmentText: 'stale'), 1, 1),
        throwsStateError,
      );
      expect(await database.getNovelSegments('book'), segments);
    },
  );

  test(
    'merge compatible labels, then reject undo over newer manual work',
    () async {
      final result = (await editor.merge(
        segments.take(2).toList(),
        separator: '',
      )).single;
      expect(
        result.segmentText,
        segments.take(2).map((s) => s.segmentText).join(),
      );
      expect(
        (await characters.load('book')).annotations[result.id]!.locked,
        isTrue,
      );
      await AnnotationRepository(database).apply('book', [
        SegmentAnnotation(
          segmentId: result.id,
          projectId: 'book',
          textRevision: novelTextRevision(result.segmentText),
          kind: NovelSegmentKind.narrator,
        ),
      ]);
      await expectLater(editor.undo('book'), throwsStateError);
      expect(
        (await characters.load('book')).annotations[result.id]!.characterId,
        isNull,
      );
    },
  );

  test(
    'merge mixed speakers leaves attribution pending rather than copying first',
    () async {
      await AnnotationRepository(database).apply('book', [
        SegmentAnnotation(
          segmentId: segments[1].id,
          projectId: 'book',
          textRevision: novelTextRevision(segments[1].segmentText),
          kind: NovelSegmentKind.narrator,
        ),
      ]);
      final result = (await editor.merge(segments.take(2).toList())).single;
      expect((await characters.load('book')).annotations[result.id], isNull);
      expect(await editor.undo('book'), isTrue);
      expect(
        (await characters.load(
          'book',
        )).annotations[segments[0].id]!.characterId,
        character,
      );
    },
  );

  test(
    'styles inherit voice independently, category override and explicit sentence win',
    () async {
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-a',
      );
      final preferences = RolePreferences(database);
      await preferences.setStyle(
        projectId: 'book',
        characterId: character,
        kind: NovelSegmentKind.dialogue,
        instruction: '轻声',
      );
      await preferences.setStyle(
        projectId: 'book',
        characterId: character,
        chapterId: 'book-chapter',
        kind: NovelSegmentKind.dialogue,
        voiceAssetId: 'voice-b',
      );
      ResolvedNovelVoice resolve(NovelRoleSnapshot roles) =>
          NovelVoiceResolver.resolve(
            segmentId: segments[0].id,
            chapterId: 'book-chapter',
            kind: NovelSegmentKind.dialogue,
            roles: roles,
            availableVoiceIds: {'voice-a', 'voice-b'},
          );
      final roles = await characters.load('book');
      expect(
        roles.characters.single.identityKind,
        CharacterIdentityKind.anonymous,
      );
      expect(resolve(roles).voiceAssetId, 'voice-b');
      expect(resolve(roles).instruction, '轻声');
      await AnnotationRepository(database).apply('book', [
        SegmentAnnotation(
          segmentId: segments[0].id,
          projectId: 'book',
          characterId: character,
          textRevision: novelTextRevision(segments[0].segmentText),
          kind: NovelSegmentKind.dialogue,
          voiceAssetId: 'voice-a',
          instruction: '坚定',
        ),
      ]);
      expect(resolve(await characters.load('book')).voiceAssetId, 'voice-a');
      expect(resolve(await characters.load('book')).instruction, '坚定');
      await expectLater(
        preferences.setStyle(
          projectId: 'book',
          characterId: character,
          chapterId: 'other-book-chapter',
          kind: NovelSegmentKind.dialogue,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'character split moves only chosen lines, copies styles, undo restores attribution',
    () async {
      await characters.bindVoice(
        projectId: 'book',
        characterId: character,
        voiceAssetId: 'voice-a',
      );
      await RolePreferences(database).setStyle(
        projectId: 'book',
        characterId: character,
        kind: NovelSegmentKind.thought,
        voiceAssetId: 'voice-b',
        instruction: '内心',
      );
      final newId = await CharacterSplitService(database).split(
        projectId: 'book',
        sourceId: character,
        name: '另一位路人',
        expected: [segments[1]],
      );
      final roles = await characters.load('book');
      expect(roles.annotations[segments[0].id]!.characterId, character);
      expect(roles.annotations[segments[1].id]!.characterId, newId);
      expect(roles.annotations[segments[1].id]!.locked, isTrue);
      expect(roles.bindings.where((b) => b.characterId == newId), hasLength(2));
      await AnnotationRepository(database).undo('book');
      expect(
        (await characters.load(
          'book',
        )).annotations[segments[1].id]!.characterId,
        character,
      );
    },
  );
}
