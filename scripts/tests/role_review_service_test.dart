import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/services/novel/role_review_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_review.dart';
import 'support/role_review_fixture.dart';
import 'support/role_skill_fixture.dart';

void main() {
  late RoleReviewFixture f;
  setUp(() async {
    f = RoleReviewFixture();
    await f.init();
  });
  tearDown(() => f.close());
  test('batched reads feed evidence to a proposal-only finish', () async {
    var turn = 0;
    final client = ReviewLlm((input, token) async {
      if (turn++ == 0) {
        return {
          'actions': [
            {'action': 'search_text', 'query': '许宁'},
            {'action': 'inspect_character', 'query': '林舟'},
            {'action': 'inspect_character', 'query': 'guard'},
          ],
        };
      }
      expect(input['lastToolResults'], hasLength(3));
      return {
        'actions': [newPerson(), patch(1, 'new:xu'), patch(2, 'lin'), finish()],
      };
    });
    final session = await f.service.run(
      projectId: 'book',
      chapterId: 'book-chapter',
      provider: f.provider,
      model: 'fake',
      client: client,
    );
    expect(session.status, 'ready');
    expect(session.calls, 2);
    expect(session.reads, 3);
    expect(session.proposals, hasLength(3));
    expect(session.reportedTokens, 200);
    expect(client.outputLimit, 1600);
    expect(client.fallback, isFalse);
    expect((await f.characters.load('book')).characters, hasLength(3));
    expect(
      (await f.characters.load('book')).annotations['sentence-2']!.characterId,
      'zhou',
    );
  });
  test('budget stops a repeated reader without another paid attempt', () async {
    final client = ReviewLlm(
      (input, token) async => {
        'actions': [
          {'action': 'read_context', 'segmentId': 'sentence-0', 'radius': 0},
        ],
      },
    );
    final s = await f.service.run(
      projectId: 'book',
      chapterId: 'book-chapter',
      provider: f.provider,
      model: 'fake',
      client: client,
      budget: const RoleReviewBudget(maxCalls: 2),
    );
    expect(s.status, 'budgetExhausted');
    expect(client.calls, 2);
    expect(s.reads, 1);
    await expectLater(
      f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        resume: true,
        client: client,
      ),
      throwsStateError,
    );
    expect(client.calls, 2);
  });
  test('too-small input budget refuses before inference', () async {
    final client = ReviewLlm(
      (input, token) async => {
        'actions': [finish()],
      },
    );
    final s = await f.service.run(
      projectId: 'book',
      chapterId: 'book-chapter',
      provider: f.provider,
      model: 'fake',
      client: client,
      budget: const RoleReviewBudget(inputBytes: 2000),
    );
    expect(client.calls, 0);
    expect(s.calls, 0);
    expect(s.status, 'budgetExhausted');
  });
  test(
    'cancellation keeps the reserved unknown charge and is resumable',
    () async {
      final started = Completer<void>();
      final client = ReviewLlm((input, token) async {
        started.complete();
        final gate = Completer<Map<String, dynamic>>();
        final remove = token.onCancel(
          () => gate.completeError(const TtsCancelledException()),
        );
        return gate.future.whenComplete(remove);
      });
      final running = f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        client: client,
        budget: const RoleReviewBudget(maxTokens: 40000),
      );
      await started.future;
      f.service.pause('book');
      final s = await running;
      expect(s.status, 'paused');
      expect(s.calls, 1);
      expect(s.chargedTokens, greaterThan(0));
      expect(s.reportedTokens, 0);
      expect(s.proposals, isEmpty);
      final client2 = ReviewLlm(
        (input, token) async => {
          'actions': [finish()],
        },
      );
      final done = await f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        resume: true,
        client: client2,
      );
      expect(done.status, 'ready');
      expect(done.calls, 2);
    },
  );
  test('a second service cannot claim an active persistent lease', () async {
    final started = Completer<void>(), gate = Completer<void>();
    final client = ReviewLlm((input, token) async {
      started.complete();
      await gate.future;
      return {
        'actions': [finish()],
      };
    });
    final running = f.service.run(
      projectId: 'book',
      chapterId: 'book-chapter',
      provider: f.provider,
      model: 'fake',
      client: client,
    );
    await started.future;
    final second = RoleReviewService(
      f.database,
      TtsQueueService.instance,
      loadSkill: loadTestRoleSkill,
    );
    await expectLater(
      second.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        client: client,
      ),
      throwsStateError,
    );
    expect(client.calls, 1);
    second.dispose();
    gate.complete();
    await running;
  });
  test('malformed action batches retain no partial proposal', () async {
    final client = ReviewLlm(
      (input, token) async => {
        'actions': [
          newPerson(),
          {
            ...patch(2, 'lin'),
            'evidence': [anchor(2, '伪造正文')],
          },
        ],
      },
    );
    await expectLater(
      f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        client: client,
      ),
      throwsFormatException,
    );
    final saved = (await f.service.repository.load('book', 'book-chapter'))!;
    expect(saved.status, 'failed');
    expect(saved.proposals, isEmpty);
    expect(saved.calls, 1);
  });

  test('evidence outside a truncated tool excerpt was never read', () async {
    final long = '${List.filled(500, '长').join()}许宁站在门后';
    await (f.database.update(f.database.novelSegments)
          ..where((t) => t.id.equals('sentence-0')))
        .write(db.NovelSegmentsCompanion(segmentText: Value(long)));
    var turn = 0;
    final client = ReviewLlm(
      (input, token) async => turn++ == 0
          ? {
              'actions': [
                {
                  'action': 'read_context',
                  'segmentId': 'sentence-0',
                  'radius': 0,
                },
              ],
            }
          : {
              'actions': [
                {
                  ...newPerson(),
                  'evidence': [anchor(0, '许宁站在门后')],
                },
              ],
            },
    );
    await expectLater(
      f.service.run(
        projectId: 'book',
        chapterId: 'book-chapter',
        provider: f.provider,
        model: 'fake',
        targetIds: ['sentence-1'],
        client: client,
      ),
      throwsFormatException,
    );
    final saved = (await f.service.repository.load('book', 'book-chapter'))!;
    expect(saved.proposals, isEmpty);
    expect(saved.reads, 1);
    expect(saved.excerpts['sentence-0']!.join(), isNot(contains('许宁站在门后')));
  });

  test(
    'failed transport retains reservation and redacts the configured secret',
    () async {
      final provider = f.provider.copyWith(apiKey: 'test-secret-credential');
      final client = ReviewLlm(
        (_, _) async => throw StateError('network test-secret-credential'),
      );
      await expectLater(
        f.service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: provider,
          model: 'fake',
          client: client,
        ),
        throwsA(predicate((e) => !'$e'.contains('test-secret-credential'))),
      );
      final saved = (await f.service.repository.load('book', 'book-chapter'))!;
      expect(saved.calls, 1);
      expect(saved.chargedTokens, greaterThan(0));
      expect(saved.reportedTokens, 0);
      expect(saved.error, contains('[REDACTED]'));
    },
  );

  test('reads cannot escape the chapter or execute unknown actions', () async {
    for (final action in [
      {'action': 'read_context', 'segmentId': 'foreign-segment', 'radius': 0},
      {
        'action': 'execute_sql',
        'key': 'bad',
        'reason': 'bad',
        'evidence': [anchor(0)],
      },
    ]) {
      final client = ReviewLlm(
        (_, _) async => {
          'actions': [action],
        },
      );
      await expectLater(
        f.service.run(
          projectId: 'book',
          chapterId: 'book-chapter',
          provider: f.provider,
          model: 'fake',
          client: client,
        ),
        throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
      );
      expect(
        (await f.service.repository.load('book', 'book-chapter'))!.proposals,
        isEmpty,
      );
    }
    expect((await f.characters.load('book')).characters, hasLength(3));
  });
}
