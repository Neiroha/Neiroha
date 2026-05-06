import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'path_service.dart';
import 'storage_service.dart';

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
      final raw = (await _readTextFile(file)).trim();
      if (raw.isEmpty) {
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

      final segments = splitNovelText(raw);
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

class NovelTextSegment {
  final String text;
  final String type;

  const NovelTextSegment({required this.text, required this.type});
}

List<NovelTextSegment> splitNovelText(String text) {
  final blocks = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n\s*\n|(?<=\n)(?=\s*第.{1,12}[章节卷回幕])'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty);

  final out = <NovelTextSegment>[];
  for (final block in blocks) {
    for (final segment in _parseByQuotes(block)) {
      for (final chunk in _splitToReadableChunks(segment.text)) {
        out.add(NovelTextSegment(text: chunk, type: segment.type));
      }
    }
  }
  return out;
}

List<NovelTextSegment> _parseByQuotes(String text) {
  final parts = text.split(
    RegExp(r'([“][\s\S]*?[”]|[「][\s\S]*?[」]|"[\s\S]*?")'),
  );
  final out = <NovelTextSegment>[];
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final isDialogue = RegExp(
      r'^([“][\s\S]*[”]|[「][\s\S]*[」]|"[\s\S]*")$',
    ).hasMatch(trimmed);
    out.add(
      NovelTextSegment(
        text: trimmed,
        type: isDialogue ? 'dialogue' : 'narrator',
      ),
    );
  }
  return out;
}

List<String> _splitToReadableChunks(String text) {
  const minLength = 60;
  const maxLength = 180;
  final parts = text.split(RegExp(r'([。！？；;.!?\n]+|[,，、])'));
  final chunks = <String>[];
  var current = '';
  for (final part in parts) {
    if (part.isEmpty) continue;
    current += part;
    final isBreak = RegExp(r'^[。！？；;.!?\n]+$').hasMatch(part);
    if ((current.length >= minLength && isBreak) ||
        current.length >= maxLength) {
      chunks.add(current.trim());
      current = '';
    }
  }
  if (current.trim().isNotEmpty) chunks.add(current.trim());
  return chunks;
}
