import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'path_service.dart';
import 'novel_dialogue_rules_service.dart';
import 'storage_service.dart';
import '../../domain/text/novel_semantic_segmenter.dart';
export '../../domain/text/novel_semantic_segmenter.dart' show NovelTextSegment;

class NovelImportService {
  NovelImportService(this._db, this._storage);

  final AppDatabase _db;
  final StorageService _storage;

  static const _uuid = Uuid();

  Future<NovelImportReport> importFiles({
    required String projectId,
    required List<File> files,
    bool replaceExisting = true,
  }) async {
    final textFiles = files.where((file) => _isTextFile(file.path)).toList()
      ..sort(
        (a, b) => _naturalCompare(
          p.basenameWithoutExtension(a.path),
          p.basenameWithoutExtension(b.path),
        ),
      );

    if (textFiles.isEmpty) {
      return const NovelImportReport(
        chapterCount: 0,
        segmentCount: 0,
        skippedCount: 0,
      );
    }

    final project = await _db.getNovelProjectById(projectId);
    if (project == null) {
      throw StateError('Novel project $projectId not found');
    }
    final slug = await _storage.ensureNovelProjectSlug(project.id);
    final sourceDir = await PathService.instance.novelReaderSourceDir(slug);

    if (replaceExisting && await sourceDir.exists()) {
      await for (final entity in sourceDir.list(followLinks: false)) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }

    final dialogueRules = await loadDialogueRules();
    var globalIndex = 0;
    var chapterCount = 0;
    var segmentCount = 0;
    var skippedCount = files.length - textFiles.length;
    final chapterRows = <NovelChaptersCompanion>[];
    final segmentRows = <NovelSegmentsCompanion>[];

    for (
      var chapterIndex = 0;
      chapterIndex < textFiles.length;
      chapterIndex++
    ) {
      final file = textFiles[chapterIndex];
      final raw = await _readTextFile(file);
      if (raw.trim().isEmpty) {
        skippedCount++;
        continue;
      }

      final title = _chapterTitleFromFile(file.path);
      final chapterId = _uuid.v4();
      final copiedPath = PathService.dedupeFilename(
        sourceDir,
        p.basenameWithoutExtension(file.path),
        p.extension(file.path).isEmpty ? '.txt' : p.extension(file.path),
      );
      try {
        await file.copy(copiedPath);
      } catch (_) {
        // Import still succeeds even if the source archive copy fails.
      }

      chapterRows.add(
        NovelChaptersCompanion(
          id: Value(chapterId),
          projectId: Value(projectId),
          orderIndex: Value(chapterCount),
          title: Value(title),
          sourcePath: Value(copiedPath),
          rawText: Value(raw),
        ),
      );

      final segments = splitNovelText(raw, dialogueRules: dialogueRules);
      for (
        var segmentIndex = 0;
        segmentIndex < segments.length;
        segmentIndex++
      ) {
        final segment = segments[segmentIndex];
        segmentRows.add(
          NovelSegmentsCompanion(
            id: Value(_uuid.v4()),
            projectId: Value(projectId),
            chapterId: Value(chapterId),
            globalIndex: Value(globalIndex),
            orderIndex: Value(segmentIndex),
            segmentText: Value(segment.text),
            segmentType: Value(segment.type),
          ),
        );
        globalIndex++;
        segmentCount++;
      }
      chapterCount++;
    }

    final updatedProject = project.copyWith(
      currentGlobalIndex: 0,
      updatedAt: DateTime.now(),
    );
    if (replaceExisting) {
      await _db.replaceNovelContent(
        projectId: projectId,
        chapters: chapterRows,
        segments: segmentRows,
        project: updatedProject,
      );
    } else {
      await _db.transaction(() async {
        await _db.batch((b) {
          if (chapterRows.isNotEmpty) {
            b.insertAll(_db.novelChapters, chapterRows);
          }
          if (segmentRows.isNotEmpty) {
            b.insertAll(_db.novelSegments, segmentRows);
          }
        });
        await _db.updateNovelProject(updatedProject);
      });
    }

    return NovelImportReport(
      chapterCount: chapterCount,
      segmentCount: segmentCount,
      skippedCount: skippedCount,
    );
  }

  Future<List<NovelDialogueRule>> loadDialogueRules() {
    return NovelDialogueRulesService(_db).load();
  }

  Future<void> saveDialogueRules(List<NovelDialogueRule> rules) {
    return NovelDialogueRulesService(_db).save(rules);
  }

  Future<NovelImportReport> importFolder({
    required String projectId,
    required Directory directory,
    bool replaceExisting = true,
  }) async {
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) files.add(entity);
    }
    return importFiles(
      projectId: projectId,
      files: files,
      replaceExisting: replaceExisting,
    );
  }

  static Future<String> _readTextFile(File file) async {
    final bytes = await file.readAsBytes();
    return decodeTextBytes(Uint8List.fromList(bytes));
  }

  static String decodeTextBytes(Uint8List bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = Uint8List.sublistView(data, 3);
    }
    try {
      return utf8.decode(data);
    } catch (_) {
      return latin1.decode(data, allowInvalid: true);
    }
  }

  static bool _isTextFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.txt' || ext == '.text' || ext == '.md';
  }

  static String _chapterTitleFromFile(String path) {
    final stem = p.basenameWithoutExtension(path).trim();
    return stem.isEmpty ? 'Chapter' : stem;
  }

  static int _naturalCompare(String a, String b) {
    final ax = _naturalParts(a);
    final bx = _naturalParts(b);
    for (var i = 0; i < ax.length && i < bx.length; i++) {
      final av = ax[i];
      final bv = bx[i];
      final ai = int.tryParse(av);
      final bi = int.tryParse(bv);
      final cmp = ai != null && bi != null
          ? ai.compareTo(bi)
          : av.toLowerCase().compareTo(bv.toLowerCase());
      if (cmp != 0) return cmp;
    }
    return ax.length.compareTo(bx.length);
  }

  static List<String> _naturalParts(String value) {
    final matches = RegExp(r'\d+|\D+').allMatches(value);
    return [for (final match in matches) match.group(0)!];
  }
}

class NovelImportReport {
  final int chapterCount;
  final int segmentCount;
  final int skippedCount;

  const NovelImportReport({
    required this.chapterCount,
    required this.segmentCount,
    required this.skippedCount,
  });
}

List<NovelTextSegment> splitNovelText(
  String text, {
  List<NovelDialogueRule>? dialogueRules,
}) {
  final rules = (dialogueRules ?? NovelDialogueRulesService.builtInRules).where(
    (r) => r.enabled && r.pattern.trim().isNotEmpty,
  );
  final quotes = <String, String>{};
  final custom = <RegExp>[];
  for (final rule in rules) {
    final builtIn = NovelDialogueRulesService.builtInRules
        .where((r) => r.pattern == rule.pattern)
        .firstOrNull;
    final opener = switch (builtIn?.id) {
      'builtin.cn_double_quote' => '“',
      'builtin.en_double_quote' => '"',
      'builtin.corner_quote' => '「',
      'builtin.white_corner_quote' => '『',
      _ => null,
    };
    if (opener != null) {
      quotes[opener] = NovelSemanticSegmenter.defaultQuotes[opener]!;
    } else {
      try {
        custom.add(RegExp(rule.pattern, multiLine: true, dotAll: true));
      } on FormatException {
        /* Invalid user rules do not prevent import. */
      }
    }
  }
  return NovelSemanticSegmenter.split(
    text,
    quotes: quotes,
    extraDialogueRules: custom,
  );
}

String resolveNovelSegmentType(
  String text, {
  List<NovelDialogueRule>? dialogueRules,
}) {
  final parts = splitNovelText(text, dialogueRules: dialogueRules);
  return parts.isNotEmpty && parts.every((s) => s.type == 'dialogue')
      ? 'dialogue'
      : 'narrator';
}

bool isNovelPunctuationOnly(String text) {
  final compact = text
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'["“”「」『』〝〞＂《》〈〉（）()\[\]{}【】]'), '');
  if (compact.isEmpty) return true;
  return !RegExp(
    r'[A-Za-z0-9\u3400-\u9FFF\uF900-\uFAFFぁ-んァ-ン가-힣]',
  ).hasMatch(compact);
}
