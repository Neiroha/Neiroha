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

class NovelTextSegment {
  final String text;
  final String type;

  const NovelTextSegment({required this.text, required this.type});
}

List<NovelTextSegment> splitNovelText(
  String text, {
  List<NovelDialogueRule>? dialogueRules,
}) {
  final blocks = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n\s*\n|(?<=\n)(?=\s*第.{1,12}[章节卷回幕])'))
      .map((block) => block.trim())
      .where((block) => block.isNotEmpty);

  final out = <NovelTextSegment>[];
  for (final block in blocks) {
    for (final segment in _parseByDialogueRules(block, dialogueRules)) {
      for (final chunk in _splitToReadableChunks(segment.text)) {
        out.add(NovelTextSegment(text: chunk, type: segment.type));
      }
    }
  }
  return _mergeLooseQuoteFragments(out);
}

String resolveNovelSegmentType(
  String text, {
  List<NovelDialogueRule>? dialogueRules,
}) {
  return _matchesDialogueRule(text, dialogueRules) ? 'dialogue' : 'narrator';
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

List<NovelTextSegment> _parseByDialogueRules(
  String text,
  List<NovelDialogueRule>? dialogueRules,
) {
  final ranges = _dialogueRanges(text, dialogueRules);
  if (ranges.isEmpty) {
    return [NovelTextSegment(text: text.trim(), type: 'narrator')];
  }

  final out = <NovelTextSegment>[];
  var cursor = 0;
  for (final range in ranges) {
    if (range.start < cursor) continue;
    _addTextSegment(out, text.substring(cursor, range.start), 'narrator');
    _addTextSegment(out, text.substring(range.start, range.end), 'dialogue');
    cursor = range.end;
  }
  _addTextSegment(out, text.substring(cursor), 'narrator');
  return out;
}

bool _matchesDialogueRule(String text, List<NovelDialogueRule>? dialogueRules) {
  final clean = text.trim();
  if (clean.isEmpty) return false;
  for (final range in _dialogueRanges(clean, dialogueRules)) {
    if (range.start == 0 && range.end == clean.length) return true;
  }
  return false;
}

List<_TextRange> _dialogueRanges(
  String text,
  List<NovelDialogueRule>? dialogueRules,
) {
  final rules = (dialogueRules ?? NovelDialogueRulesService.builtInRules).where(
    (rule) => rule.enabled && rule.pattern.trim().isNotEmpty,
  );
  final ranges = <_TextRange>[];
  for (final rule in rules) {
    try {
      final regex = RegExp(rule.pattern, multiLine: true, dotAll: true);
      for (final match in regex.allMatches(text)) {
        if (match.start < match.end) {
          ranges.add(_TextRange(match.start, match.end));
        }
      }
    } on FormatException {
      continue;
    }
  }
  ranges.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart == 0 ? b.end.compareTo(a.end) : byStart;
  });

  final merged = <_TextRange>[];
  for (final range in ranges) {
    if (merged.isEmpty || range.start >= merged.last.end) {
      merged.add(range);
      continue;
    }
    if (range.end > merged.last.end) {
      final last = merged.removeLast();
      merged.add(_TextRange(last.start, range.end));
    }
  }
  return merged;
}

class _TextRange {
  final int start;
  final int end;

  const _TextRange(this.start, this.end);
}

void _addTextSegment(List<NovelTextSegment> out, String text, String type) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return;
  out.add(NovelTextSegment(text: trimmed, type: type));
}

List<String> _splitToReadableChunks(String text) {
  const minLength = 20;
  const maxLength = 160;
  final clean = text.trim();
  if (clean.isEmpty) return const [];

  final breaks = RegExp(r'[。！？；;.!?\n]+|[,，、]+');
  final chunks = <String>[];
  var start = 0;
  for (final match in breaks.allMatches(clean)) {
    if (match.end <= start) continue;
    final end = _includeTrailingClosingQuotes(clean, match.end);
    final length = end - start;
    final punctuation = match.group(0) ?? '';
    final isStrongBreak = RegExp(r'[。！？；;.!?\n]').hasMatch(punctuation);
    if ((length >= minLength && isStrongBreak) || length >= maxLength) {
      _appendBoundedChunks(chunks, clean.substring(start, end));
      start = end;
    }
  }
  _appendBoundedChunks(chunks, clean.substring(start));
  return chunks;
}

int _includeTrailingClosingQuotes(String text, int index) {
  var cursor = index;
  while (cursor < text.length && text[cursor].trim().isEmpty) {
    cursor++;
  }
  var end = cursor;
  while (end < text.length && _isClosingQuote(text[end])) {
    if (text[end] == '"' && !_looksLikeClosingAsciiQuote(text, end)) break;
    end++;
  }
  return end == cursor ? index : end;
}

bool _looksLikeClosingAsciiQuote(String text, int index) {
  var next = index + 1;
  while (next < text.length && text[next].trim().isEmpty) {
    next++;
  }
  if (next >= text.length) return true;
  return RegExp(r'[。！？；;.!?,，、)\]】》」』”]').hasMatch(text[next]);
}

bool _isClosingQuote(String value) {
  return const {
    '"',
    '”',
    '」',
    '』',
    '〞',
    '＂',
    '）',
    ')',
    ']',
    '】',
    '》',
    '〉',
  }.contains(value);
}

List<NovelTextSegment> _mergeLooseQuoteFragments(
  List<NovelTextSegment> segments,
) {
  final out = <NovelTextSegment>[];
  for (final segment in segments) {
    if (_isLooseQuoteOnly(segment.text) && out.isNotEmpty) {
      final previous = out.removeLast();
      out.add(
        NovelTextSegment(
          text: '${previous.text}${segment.text}',
          type: previous.type,
        ),
      );
      continue;
    }
    out.add(segment);
  }
  return out;
}

bool _isLooseQuoteOnly(String text) {
  final clean = text.replaceAll(RegExp(r'\s+'), '');
  if (clean.isEmpty) return false;
  return clean.split('').every(_isClosingQuote);
}

void _appendBoundedChunks(List<String> chunks, String text) {
  const maxLength = 160;
  var clean = _attachDetachedClosingQuote(text.trim());
  while (clean.length > maxLength) {
    chunks.add(clean.substring(0, maxLength).trim());
    clean = _attachDetachedClosingQuote(clean.substring(maxLength).trim());
  }
  if (clean.isNotEmpty) chunks.add(clean);
}

String _attachDetachedClosingQuote(String text) {
  return text.replaceFirstMapped(
    RegExp(r'\s+([”」』〞＂"\)\]】》〉])$'),
    (match) => match.group(1) ?? '',
  );
}
