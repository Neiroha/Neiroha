import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'support/role_review_fixture.dart';
import 'support/review_live_client.dart';
import 'support/role_skill_fixture.dart';
import '../tools/run_live_tests.dart' show redactCredentials;

void main() {
  final enabled = Platform.environment['NEIROHA_LIVE_REVIEW'] == '1';
  final key = Platform.environment['OPENAI_TEST_API_KEY'] ?? '';
  final model = Platform.environment['OPENAI_ROLE_MODEL'] ?? 'gpt-6-luna';
  final output = Directory(
    Platform.environment['OPENAI_ROLE_OUT_DIR'] ??
        '.dart_tool/agent-p1-evaluation',
  );
  final ledger = ReviewLiveLedger();
  final cases = <Map<String, Object?>>[];
  final filter = (Platform.environment['OPENAI_ROLE_CASES'] ?? '').split(',');
  void save() {
    output.createSync(recursive: true);
    File('${output.path}/capture.json').writeAsStringSync(
      redactCredentials(
        const JsonEncoder.withIndent('  ').convert({
          'model': model,
          'maxCalls': 6,
          'maxTokens': 40000,
          'calls': ledger.calls,
          'chargedTokens': ledger.charged,
          'reportedTokens': ledger.reported,
          'requests': ledger.requests,
          'cases': cases,
        }),
        key,
      ),
    );
  }

  for (final id in ['identity', 'chat', 'merge']) {
    test(
      'paid bounded local review: $id',
      () async {
        expect(key, isNotEmpty);
        // An existing artifact is never overwritten by another paid run.
        if (cases.isEmpty && File('${output.path}/capture.json').existsSync()) {
          fail(
            'Choose a fresh output directory; completed/failed captures are preserved.',
          );
        }
        final f = RoleReviewFixture();
        await f.init();
        addTearDown(f.close);
        final text = id != 'chat'
            ? reviewTexts
            : ['【群聊/许宁】：我是许宁，刚进群。', '【群聊/林舟】：许宁，等等我。', '门卫老周在一旁听着，没有说话。'];
        if (id == 'chat') {
          for (var i = 0; i < 3; i++) {
            await (f.database.update(f.database.novelSegments)
                  ..where((t) => t.id.equals('sentence-$i')))
                .write(db.NovelSegmentsCompanion(segmentText: Value(text[i])));
            await AnnotationRepository(f.database).apply('book', [
              SegmentAnnotation(
                segmentId: 'sentence-$i',
                projectId: 'book',
                textRevision: novelTextRevision(text[i]),
                characterId: i == 2 ? null : 'zhou',
                kind: i == 2
                    ? NovelSegmentKind.narrator
                    : NovelSegmentKind.dialogue,
                reviewState: NovelReviewState.inferred,
              ),
            ], fromAi: true);
          }
        }
        final entry = <String, Object?>{
          'id': id,
          'skill': (await loadTestRoleSkill()).identity,
          'text': text,
          'before': reviewSnapshotJson(await f.characters.load('book')),
        };
        cases.add(entry);
        save();
        RoleReviewSession? session;
        try {
          session = await f.service.run(
            projectId: 'book',
            chapterId: 'book-chapter',
            provider: f.provider,
            model: model,
            targetIds: id == 'merge'
                ? ['sentence-0']
                : ['sentence-0', 'sentence-1', 'sentence-2'],
            budget: RoleReviewBudget(maxCalls: id == 'merge' ? 1 : 3),
            client: ReviewLiveClient(key, model, id, ledger, save),
          );
          entry['session'] = session.toJson();
          expect(
            reviewSnapshotJson(await f.characters.load('book')),
            entry['before'],
            reason: 'The model may only propose.',
          );
          if (session.canApply) {
            // Simulate explicit acceptance only in the isolated test database.
            await f.service.repository.apply(
              'book',
              'book-chapter',
              session.id,
              session.proposals.map((p) => p.key).toSet(),
            );
          }
          final after = await f.characters.load('book');
          entry['after'] = reviewSnapshotJson(after);
          expect(
            after.annotations.values.every(
              (a) => !a.locked && a.reviewState != NovelReviewState.confirmed,
            ),
            isTrue,
          );
          expect(
            (await f.database.getNovelSegments(
              'book',
            )).map((s) => s.segmentText),
            text,
          );
          expect(ledger.calls, lessThanOrEqualTo(6));
          expect(ledger.charged, lessThanOrEqualTo(40000));
          stdout.writeln(
            '$id: ${session.proposals.length} proposals; ${session.calls} calls; ${session.reportedTokens} tokens; ${session.status}.',
          );
        } catch (error) {
          entry['error'] = '$error';
          entry['session'] = (await f.service.repository.load(
            'book',
            'book-chapter',
          ))?.toJson();
          rethrow;
        } finally {
          save();
        }
      },
      skip:
          !enabled ||
          (id == 'merge' && !filter.contains(id)) ||
          (filter.any((s) => s.isNotEmpty) && !filter.contains(id)),
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
