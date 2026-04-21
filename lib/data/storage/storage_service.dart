import 'dart:io';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import 'path_service.dart';

/// Orchestrates disk + SQLite consistency for archived audio.
///
/// Responsibilities:
/// - Load/persist the user-configured voice-asset root.
/// - Scan audio-bearing rows at startup and mark rows whose files are gone.
/// - Offer a "clear all archived audio" operation that wipes disk + DB rows.
class StorageService {
  StorageService(this._db);

  static const String kVoiceAssetRootKey = 'voiceAssetRoot';

  final AppDatabase _db;

  /// Reads the persisted voice-asset root (if any) and applies it to
  /// [PathService]. Call once after DB init.
  Future<void> applyPersistedRoot() async {
    final override = await _db.getSetting(kVoiceAssetRootKey);
    PathService.instance.applyVoiceAssetRootOverride(override);
  }

  Future<void> setVoiceAssetRoot(String? absolutePath) async {
    final trimmed = absolutePath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _db.deleteSetting(kVoiceAssetRootKey);
      PathService.instance.applyVoiceAssetRootOverride(null);
    } else {
      // Pre-create so the user gets immediate feedback if the dir is invalid.
      final dir = Directory(trimmed);
      if (!await dir.exists()) await dir.create(recursive: true);
      await _db.setSetting(kVoiceAssetRootKey, trimmed);
      PathService.instance.applyVoiceAssetRootOverride(trimmed);
    }
  }

  /// Scan every audio-path column and flip the `missing` flag to match
  /// disk reality. Never deletes rows — a missing file might mean the user
  /// moved the voice-asset root and we should prompt them, not destroy data.
  Future<StorageScanReport> scan() async {
    var checked = 0;
    var missing = 0;
    var recovered = 0;

    Future<void> visit({
      required String? path,
      required bool wasMissing,
      required Future<void> Function(bool) mark,
    }) async {
      if (path == null || path.isEmpty) return;
      checked++;
      final exists = await File(path).exists();
      final nowMissing = !exists;
      if (nowMissing) missing++;
      if (!nowMissing && wasMissing) recovered++;
      if (nowMissing != wasMissing) await mark(nowMissing);
    }

    for (final row in await _db.getAllQuickTtsHistoryRaw()) {
      await visit(
        path: row.audioPath,
        wasMissing: row.missing,
        mark: (m) => _db.markQuickTtsMissing(row.id, m).then((_) {}),
      );
    }
    for (final row in await _db.getAllPhaseSegmentsRaw()) {
      await visit(
        path: row.audioPath,
        wasMissing: row.missing,
        mark: (m) => _db.markPhaseSegmentMissing(row.id, m).then((_) {}),
      );
    }
    for (final row in await _db.getAllDialogLinesRaw()) {
      await visit(
        path: row.audioPath,
        wasMissing: row.missing,
        mark: (m) => _db.markDialogLineMissing(row.id, m).then((_) {}),
      );
    }
    for (final row in await _db.getAllAudioTracksRaw()) {
      await visit(
        path: row.audioPath,
        wasMissing: row.missing,
        mark: (m) => _db.markAudioTrackMissing(row.id, m).then((_) {}),
      );
    }
    for (final row in await _db.getAllTimelineClipsRaw()) {
      await visit(
        path: row.audioPath,
        wasMissing: row.missing,
        mark: (m) => _db.markTimelineClipMissing(row.id, m).then((_) {}),
      );
    }

    return StorageScanReport(
      checked: checked,
      missing: missing,
      recovered: recovered,
    );
  }

  /// Calculate the aggregate footprint under the configured voice-asset root.
  Future<StorageUsage> measureVoiceAssetRoot() async {
    final root = PathService.instance.voiceAssetRoot;
    if (!await root.exists()) {
      return const StorageUsage(fileCount: 0, totalBytes: 0);
    }
    var count = 0;
    var bytes = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        count++;
        try {
          bytes += await entity.length();
        } catch (_) {}
      }
    }
    return StorageUsage(fileCount: count, totalBytes: bytes);
  }

  /// Resolve (and pin) the on-disk folder slug for a voice asset. The slug
  /// is set exactly once — the first time the character generates audio —
  /// so future renames of the display name leave the archived folder intact.
  /// Collisions against other assets' slugs are resolved with `-2`, `-3`, …
  ///
  /// Runs inside a transaction so two concurrent first-generation calls
  /// (whether for the same asset or two assets with the same sanitized
  /// name) can't both compute a slug against a stale `taken` set.
  Future<String> ensureVoiceAssetSlug(String assetId) =>
      _db.transaction(() async {
        final asset = await _db.getVoiceAssetById(assetId);
        if (asset == null) {
          throw StateError('Voice asset $assetId not found');
        }
        final existing = asset.folderSlug;
        if (existing != null && existing.isNotEmpty) return existing;

        final all = await _db.getAllVoiceAssets();
        final taken = <String>{
          for (final a in all)
            if (a.id != assetId &&
                a.folderSlug != null &&
                a.folderSlug!.isNotEmpty)
              a.folderSlug!,
        };
        final slug = _dedupeSlug(
          PathService.sanitizeSegment(asset.name, fallback: 'unnamed_voice'),
          taken,
        );
        await _db.updateVoiceAsset(asset.copyWith(folderSlug: Value(slug)));
        return slug;
      });

  /// Same as [ensureVoiceAssetSlug] but for Phase TTS projects.
  Future<String> ensurePhaseProjectSlug(String projectId) =>
      _db.transaction(() async {
        final project = await _db.getPhaseTtsProjectById(projectId);
        if (project == null) {
          throw StateError('Phase project $projectId not found');
        }
        final existing = project.folderSlug;
        if (existing != null && existing.isNotEmpty) return existing;

        final all = await _db.getAllPhaseTtsProjects();
        final taken = <String>{
          for (final p in all)
            if (p.id != projectId &&
                p.folderSlug != null &&
                p.folderSlug!.isNotEmpty)
              p.folderSlug!,
        };
        final slug = _dedupeSlug(
          PathService.sanitizeSegment(project.name, fallback: 'unnamed_project'),
          taken,
        );
        await _db.updatePhaseTtsProject(
            project.copyWith(folderSlug: Value(slug)));
        return slug;
      });

  /// Same as [ensureVoiceAssetSlug] but for Dialog TTS projects.
  Future<String> ensureDialogProjectSlug(String projectId) =>
      _db.transaction(() async {
        final project = await _db.getDialogTtsProjectById(projectId);
        if (project == null) {
          throw StateError('Dialog project $projectId not found');
        }
        final existing = project.folderSlug;
        if (existing != null && existing.isNotEmpty) return existing;

        final all = await _db.getAllDialogTtsProjects();
        final taken = <String>{
          for (final p in all)
            if (p.id != projectId &&
                p.folderSlug != null &&
                p.folderSlug!.isNotEmpty)
              p.folderSlug!,
        };
        final slug = _dedupeSlug(
          PathService.sanitizeSegment(project.name, fallback: 'unnamed_project'),
          taken,
        );
        await _db.updateDialogTtsProject(
            project.copyWith(folderSlug: Value(slug)));
        return slug;
      });

  static String _dedupeSlug(String base, Set<String> taken) {
    if (!taken.contains(base)) return base;
    var n = 2;
    while (taken.contains('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }

  /// Delete every archived audio file + wipe audio rows in SQLite.
  /// Project scripts / character configs / banks are preserved.
  /// This operation is irreversible — the caller MUST confirm with the user.
  Future<void> clearAllAudioArchives() async {
    final root = PathService.instance.voiceAssetRoot;
    if (await root.exists()) {
      // Remove only the managed subfolders so the user's own files under
      // the configured root are not touched.
      for (final name in const [
        'quick_tts',
        'phase_tts',
        'dialog_tts',
        'voice_character_ref',
      ]) {
        final sub = Directory('${root.path}${Platform.pathSeparator}$name');
        if (await sub.exists()) {
          try {
            await sub.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
    await _db.clearAllAudioArchives();
    // Clear any lingering refAudioPath references on voice characters — the
    // underlying file is now gone, so the column would just dangle.
    final assets = await _db.getAllVoiceAssets();
    for (final a in assets) {
      if (a.refAudioPath != null) {
        await _db.updateVoiceAsset(a.copyWith(
          refAudioPath: const Value(null),
          refAudioTrimStart: const Value(null),
          refAudioTrimEnd: const Value(null),
        ));
      }
    }
  }
}

class StorageScanReport {
  final int checked;
  final int missing;
  final int recovered;

  const StorageScanReport({
    required this.checked,
    required this.missing,
    required this.recovered,
  });
}

class StorageUsage {
  final int fileCount;
  final int totalBytes;

  const StorageUsage({required this.fileCount, required this.totalBytes});

  String get prettyBytes {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = totalBytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}
