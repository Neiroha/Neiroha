import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

void main() {
  late db.AppDatabase database;
  const projectId = 'p1';

  Future<List<String>> texts() async => [
    for (final s in await database.getPhaseTtsSegments(projectId))
      s.segmentText,
  ];

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime(2026);
    await database.insertBank(
      db.VoiceBanksCompanion(
        id: const Value('b1'),
        name: const Value('Cast'),
        createdAt: Value(now),
      ),
    );
    await database.insertPhaseTtsProject(
      db.PhaseTtsProjectsCompanion(
        id: const Value(projectId),
        name: const Value('P'),
        bankId: const Value('b1'),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    for (final (i, text) in ['一。', '二。', '三。'].indexed) {
      await database.insertPhaseTtsSegment(
        db.PhaseTtsSegmentsCompanion(
          id: Value('s$i'),
          projectId: const Value(projectId),
          orderIndex: Value(i),
          segmentText: Value(text),
          audioPath: Value('s$i.wav'),
        ),
      );
    }
  });

  tearDown(() => database.close());

  test('new columns default for loudness and merge settings', () async {
    final project = await database.getPhaseTtsProjectById(projectId);
    expect(project!.autoNormalizeLoudness, isFalse);
    expect(project.mergeGapSeconds, 0.3);
    final bank = await database.getBankById('b1');
    expect(bank!.loudnessTargetLufs, -16);
  });

  test('reorder moves a segment and renumbers', () async {
    await database.reorderPhaseSegment(projectId, 0, 2);
    expect(await texts(), ['二。', '三。', '一。']);
    final order = [
      for (final s in await database.getPhaseTtsSegments(projectId))
        s.orderIndex,
    ];
    expect(order, [0, 1, 2]);
  });

  test('insert, split and merge keep order and clear stale audio', () async {
    await database.insertPhaseSegmentAfter(
      projectId: projectId,
      afterId: 's0',
      id: 'new',
      text: '插入。',
    );
    expect(await texts(), ['一。', '插入。', '二。', '三。']);

    final s1 = (await database.getPhaseTtsSegments(
      projectId,
    )).firstWhere((s) => s.id == 's1');
    await database.splitPhaseSegment(s1, '二', '。', 'tail');
    expect(await texts(), ['一。', '插入。', '二', '。', '三。']);
    final split = (await database.getPhaseTtsSegments(
      projectId,
    )).firstWhere((s) => s.id == 's1');
    expect(split.audioPath, isNull);

    expect(await database.mergePhaseSegmentWithNext(projectId, 's1'), isTrue);
    expect(await texts(), ['一。', '插入。', '二。', '三。']);
    expect(await database.mergePhaseSegmentWithNext(projectId, 's2'), isFalse);
  });

  test('deleted segments come back in place on undo', () async {
    final rows = (await database.getPhaseTtsSegments(
      projectId,
    )).where((s) => s.id != 's1').toList();
    await database.deletePhaseSegments(projectId, rows.map((s) => s.id));
    expect(await texts(), ['二。']);
    await database.restorePhaseSegments(projectId, rows);
    expect(await texts(), ['一。', '二。', '三。']);
    final restored = (await database.getPhaseTtsSegments(projectId)).first;
    expect(restored.audioPath, 's0.wav');
  });
}
