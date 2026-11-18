import 'package:drift/drift.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

Future<void> seedNovelFixture(db.AppDatabase database) async {
  final now = DateTime(2026, 11, 17);
  await database.insertProvider(
    const db.TtsProvidersCompanion(
      id: Value('test-provider'),
      name: Value('Provider'),
      adapterType: Value('openaiTts'),
      baseUrl: Value('http://localhost'),
    ),
  );
  await database.insertBank(
    db.VoiceBanksCompanion(
      id: const Value('bank'),
      name: const Value('Bank'),
      createdAt: Value(now),
    ),
  );
  for (final id in ['voice-a', 'voice-b']) {
    await database.insertVoiceAsset(
      db.VoiceAssetsCompanion(
        id: Value(id),
        name: Value(id),
        providerId: const Value('test-provider'),
        taskMode: const Value('presetVoice'),
        presetVoiceName: Value(id),
      ),
    );
    await database.addMemberToBank(
      db.VoiceBankMembersCompanion(
        id: Value('member-$id'),
        bankId: const Value('bank'),
        voiceAssetId: Value(id),
      ),
    );
  }
  for (final id in ['book', 'other-book']) {
    await database.insertNovelProject(
      db.NovelProjectsCompanion(
        id: Value(id),
        name: Value(id),
        bankId: const Value('bank'),
        narratorVoiceAssetId: const Value('voice-a'),
        dialogueVoiceAssetId: const Value('voice-b'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await database.insertNovelChapter(
      db.NovelChaptersCompanion(
        id: Value('$id-chapter'),
        projectId: Value(id),
        orderIndex: const Value(0),
        title: const Value('Chapter'),
      ),
    );
  }
  for (var i = 0; i < 3; i++) {
    await database.insertNovelSegment(
      db.NovelSegmentsCompanion(
        id: Value('sentence-$i'),
        projectId: const Value('book'),
        chapterId: const Value('book-chapter'),
        orderIndex: Value(i),
        globalIndex: Value(i),
        segmentText: Value(i == 0 ? '“你好，𠮷野🌸。”' : '第 $i 句话。'),
        segmentType: const Value('dialogue'),
      ),
    );
  }
}
