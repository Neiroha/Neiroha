import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/data/adapters/llm_chat_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/annotation_repository.dart';
import 'package:neiroha/data/services/novel/character_repository.dart';
import 'package:neiroha/data/services/novel/novel_text_revision.dart';
import 'package:neiroha/data/services/novel/role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_evaluation.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';

import 'support/role_eval_chapters.dart';
import 'support/role_eval_fixture.dart';
import 'support/role_skill_fixture.dart';
import 'support/measured_role_llm.dart';

/// Opt-in paid evaluation through the production importer and analysis service.
/// Gold labels/rosters are used only for scoring, never sent to the model.
void main() {
  final replayOnly = Platform.environment['NEIROHA_ROLE_REPLAY'] == '1';
  final enabled =
      Platform.environment['NEIROHA_LIVE_ROLES'] == '1' || replayOnly;
  final key = Platform.environment['OPENAI_TEST_API_KEY'] ?? '';
  final model = Platform.environment['OPENAI_ROLE_MODEL'] ?? 'gpt-6-luna';
  final output = Directory(
    Platform.environment['OPENAI_ROLE_OUT_DIR'] ??
        '.dart_tool/live-novel-roles',
  );
  final filter = (Platform.environment['OPENAI_ROLE_CASES'] ?? '')
      .split(',')
      .where((s) => s.isNotEmpty)
      .toList();
  final files =
      Directory(
            Platform.environment['NEIROHA_ROLE_FIXTURES'] ??
                'scripts/tests/fixtures/role_assign',
          )
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var calls = 0;
  var unavailable = false;
  for (final file in files) {
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final id = fixture['id'] as String;
    test(
      'live novel roles: $id ($model)',
      () async {
        if (!replayOnly) {
          expect(
            key,
            isNotEmpty,
            reason: 'Provide a key via the opt-in launcher.',
          );
        }

        final skill = await loadTestRoleSkill();
        output.createSync(recursive: true);
        final artifact = File('${output.path}/$id.json');
        final text = fixture['text'] as String;
        final chapters = evaluationChapters(fixture);
        final chapterRevisions = chapters.map(novelTextRevision).toList();
        if (artifact.existsSync()) {
          final cached =
              jsonDecode(artifact.readAsStringSync()) as Map<String, dynamic>;
          expect(cached['model'], model);
          expect(cached['sourceRevision'], novelTextRevision(text));
          if (chapters.length > 1) {
            expect(cached['chapterRevisions'], chapterRevisions);
          }
          if (!replayOnly &&
              cached['skill'] is Map &&
              cached['skill']['sha256'] != null) {
            expect(
              cached['skill']['sha256'],
              skill.digest,
              reason: 'Use a new output directory for another skill.',
            );
          }
          if (!replayOnly) {
            expect(
              cached['segmentationVersion'],
              NovelSemanticSegmenter.version,
            );
          }
          _evaluate(
            fixture,
            (cached['labels'] as List).cast<Map<String, dynamic>>(),
          );
          stdout.writeln('$id: using completed capture (no API calls).');
          return;
        }
        if (unavailable) {
          fail('Provider unavailable; no further paid requests.');
        }
        final database = db.AppDatabase.forTesting(NativeDatabase.memory());
        final characters = CharacterRepository(database);
        final annotations = AnnotationRepository(database);
        RoleAnalysisService createService() => RoleAnalysisService(
          database,
          characters,
          annotations,
          TtsQueueService.instance,
          loadSkill: loadTestRoleSkill,
        );
        List<dynamic>? replay;
        var paidPrefix = <dynamic>[];
        Map<String, dynamic> inferenceSkill = skill.identity;
        final previousMetrics = File('${output.path}/$id.metrics.json');
        if (!replayOnly &&
            Platform.environment['NEIROHA_EVAL_RESUME'] == '1' &&
            previousMetrics.existsSync()) {
          final saved =
              jsonDecode(previousMetrics.readAsStringSync())
                  as Map<String, dynamic>;
          expect(saved['model'], model);
          expect(saved['fixture'], id);
          expect(saved['sourceRevision'], novelTextRevision(text));
          expect(saved['skill'], skill.identity);
          if (chapters.length > 1) {
            expect(saved['chapterRevisions'], chapterRevisions);
          }
          paidPrefix = (saved['requests'] as List)
              .takeWhile((r) => r['output'] is Map)
              .toList();
          stdout.writeln(
            '$id: reconstructing ${paidPrefix.length} saved stages offline, then continuing within the shared budget.',
          );
        }
        if (replayOnly) {
          final capture =
              jsonDecode(
                    File('${output.path}/$id.metrics.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          expect(capture['model'], model);
          expect(capture['fixture'], id);
          if (capture['sourceRevision'] != null) {
            expect(capture['sourceRevision'], novelTextRevision(text));
            if (chapters.length > 1) {
              expect(capture['chapterRevisions'], chapterRevisions);
            }
          }
          replay = capture['requests'] as List;
          inferenceSkill =
              capture['skill'] as Map<String, dynamic>? ??
              {'status': 'legacy-unversioned'};
        }
        final metrics = <String, Object?>{
          'model': model,
          'segmentationVersion': NovelSemanticSegmenter.version,
          'protocol': 'chatCompletions',
          'parameters': {'batchSize': 20, 'maxOutputTokens': 4096},
          'fixture': id,
          'skill': inferenceSkill,
          'processingSkill': skill.identity,
          'sourceRevision': novelTextRevision(text),
          'chapterRevisions': chapterRevisions,
          'startedAt': DateTime.now().toUtc().toIso8601String(),
          'requests': <Map<String, Object?>>[],
          'resumedPrefixCalls': paidPrefix.length,
        };
        void saveMetrics() =>
            File(
              '${output.path}/$id${replayOnly ? '.recovery' : ''}.metrics.json',
            ).writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert(metrics),
            );
        final client = MeasuredRoleLlm(
          key,
          model,
          (entry) {
            (metrics['requests'] as List).add(entry);
            saveMetrics();
          },
          () {
            if (++calls >
                (int.tryParse(
                      Platform.environment['NEIROHA_EVAL_MAX_CALLS'] ?? '',
                    ) ??
                    72)) {
              throw StateError('Global evaluation call budget reached.');
            }
          },
          replay: replay,
          paidPrefix: paidPrefix,
        );
        try {
          final checkpoints = await runEvaluationChapters(
            database: database,
            characters: characters,
            createService: createService,
            client: client,
            chapters: chapters,
            fixtureId: id,
            key: key,
            model: model,
            maxCallsPerChapter:
                int.tryParse(
                  Platform.environment['NEIROHA_EVAL_CASE_CALLS'] ?? '',
                ) ??
                12,
          );
          client.verifyReplayComplete();
          final source = await database.getNovelSegments('book');
          final roles = await characters.load('book');
          expect(roles.annotations, hasLength(source.length));
          final totalCalls = checkpoints.fold<int>(
            0,
            (sum, c) => sum + c.calls,
          );
          final labels = _partition(text, source, roles);
          final evaluation = _evaluate(fixture, labels);
          artifact.writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert({
              'model': model,
              'segmentationVersion': NovelSemanticSegmenter.version,
              'skill': inferenceSkill,
              'processingSkill': skill.identity,
              'sourceRevision': novelTextRevision(text),
              'chapterRevisions': chapterRevisions,
              'labels': labels,
              'characters': [
                for (final c in roles.characters)
                  {
                    'id': c.id,
                    'name': c.name,
                    'aliases': c.aliases,
                    'identityKind': c.identityKind.name,
                  },
              ],
              'annotations': [
                for (final a in roles.annotations.values)
                  {
                    'id': a.segmentId,
                    'characterId': a.characterId,
                    'review': a.reviewState.name,
                    'reason': a.reason,
                  },
              ],
            }),
          );
          metrics.addAll({
            'status': 'completed',
            'calls': totalCalls,
            'reviewedSegments': checkpoints.fold<int>(
              0,
              (sum, c) => sum + c.reviewedSegments,
            ),
            'reviewChanges': checkpoints.fold<int>(
              0,
              (sum, c) => sum + c.reviewChanges,
            ),
            'sceneState': checkpoints.last.scene.toJson(),
            'chapters': chapters.length,
            'segments': source.length,
            'rosterResume': true,
            'sourceUnchanged': true,
            'evaluation': evaluation.toJson(),
          });
          stdout.writeln(
            '$id: category ${evaluation.categoryCorrect}/${evaluation.evaluated}, '
            'speaker ${evaluation.speakerCorrect}/${evaluation.speakerTotal}, '
            '$totalCalls calls, ${source.length} segments.',
          );
        } catch (error) {
          final message = key.isEmpty
              ? '$error'
              : '$error'.replaceAll(key, '[REDACTED]');
          metrics.addAll({'status': 'failed', 'error': message});
          if (error is LlmChatException &&
              [401, 403, 429].contains(error.statusCode)) {
            unavailable = true;
          }
          fail(message);
        } finally {
          metrics['finishedAt'] = DateTime.now().toUtc().toIso8601String();
          saveMetrics();
          await database.close();
        }
      },
      skip: !enabled || (filter.isNotEmpty && !filter.contains(id)),
      timeout: const Timeout(Duration(minutes: 12)),
    );
  }
}

RoleEvaluationResult _evaluate(
  Map<String, dynamic> fixture,
  List<Map<String, dynamic>> labels,
) => RoleEvaluation.evaluate(
  text: fixture['text'] as String,
  gold: (fixture['gold'] as List).cast<Map<String, dynamic>>(),
  roster: (fixture['roster'] as List).cast<Map<String, dynamic>>(),
  predictions: labels.map(RolePrediction.fromJson).toList(),
);

/// Align unchanged imported characters to exact UTF-16 source offsets. Only
/// omitted whitespace is restored; any substantive rewrite fails evaluation.
List<Map<String, dynamic>> _partition(
  String text,
  List<db.NovelSegment> source,
  NovelRoleSnapshot roles,
) {
  final labels = <Map<String, dynamic>>[];
  var cursor = 0;
  final whitespace = RegExp(r'\s');
  for (final segment in source) {
    final annotation = roles.annotations[segment.id]!;
    final start = cursor;
    for (var i = 0; i < segment.segmentText.length; i++) {
      final unit = segment.segmentText[i];
      if (whitespace.hasMatch(unit)) {
        if (cursor < text.length && text[cursor] == unit) {
          cursor++;
        }
        continue;
      }
      while (cursor < text.length && whitespace.hasMatch(text[cursor])) {
        cursor++;
      }
      if (cursor >= text.length || text[cursor] != unit) {
        throw FormatException(
          'Importer changed substantive source at $cursor.',
        );
      }
      cursor++;
    }
    labels.add({
      'start': start,
      'end': cursor,
      'kind': annotation.kind.name,
      'speaker': roles.characters
          .where((c) => c.id == annotation.characterId)
          .map((c) => c.name)
          .firstOrNull,
    });
  }
  if (text.substring(cursor).trim().isNotEmpty) {
    throw const FormatException('Importer omitted substantive source.');
  }
  if (cursor < text.length) {
    labels.add({
      'start': cursor,
      'end': text.length,
      'kind': 'narrator',
      'speaker': null,
    });
  }
  return labels;
}
