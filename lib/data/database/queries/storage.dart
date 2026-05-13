part of '../app_database.dart';

extension AppDatabaseStorageQueries on AppDatabase {
  // --- App Settings (key/value) ---

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(key: Value(key), value: Value(value)),
      );

  Future<int> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  // --- Storage health / sync ---

  /// Every audio-path column grouped with its update hook. Used by the
  /// startup health check to mark rows whose files no longer exist.
  Future<int> markQuickTtsMissing(String id, bool missing) =>
      (update(quickTtsHistories)..where((t) => t.id.equals(id))).write(
        QuickTtsHistoriesCompanion(missing: Value(missing)),
      );

  Future<int> markPhaseSegmentMissing(String id, bool missing) =>
      (update(phaseTtsSegments)..where((t) => t.id.equals(id))).write(
        PhaseTtsSegmentsCompanion(missing: Value(missing)),
      );

  Future<int> markDialogLineMissing(String id, bool missing) =>
      (update(dialogTtsLines)..where((t) => t.id.equals(id))).write(
        DialogTtsLinesCompanion(missing: Value(missing)),
      );

  Future<int> markNovelSegmentMissing(String id, bool missing) =>
      (update(novelSegments)..where((t) => t.id.equals(id))).write(
        NovelSegmentsCompanion(missing: Value(missing)),
      );

  Future<int> markAudioTrackMissing(String id, bool missing) =>
      (update(audioTracks)..where((t) => t.id.equals(id))).write(
        AudioTracksCompanion(missing: Value(missing)),
      );

  Future<int> markTimelineClipMissing(String id, bool missing) =>
      (update(timelineClips)..where((t) => t.id.equals(id))).write(
        TimelineClipsCompanion(missing: Value(missing)),
      );

  Future<List<QuickTtsHistory>> getAllQuickTtsHistoryRaw() =>
      select(quickTtsHistories).get();

  Future<List<PhaseTtsSegment>> getAllPhaseSegmentsRaw() =>
      select(phaseTtsSegments).get();

  Future<List<DialogTtsLine>> getAllDialogLinesRaw() =>
      select(dialogTtsLines).get();

  Future<List<NovelSegment>> getAllNovelSegmentsRaw() =>
      select(novelSegments).get();

  Future<List<AudioTrack>> getAllAudioTracksRaw() => select(audioTracks).get();

  Future<List<TimelineClip>> getAllTimelineClipsRaw() =>
      select(timelineClips).get();

  /// Wipe every audio row + clear audio-path on project scripts. Providers,
  /// characters, banks, project scripts themselves are preserved — only the
  /// archived takes vanish. Caller is responsible for deleting files on disk.
  Future<void> clearAllAudioArchives() => transaction(() async {
    await delete(timelineClips).go();
    await delete(audioTracks).go();
    await delete(quickTtsHistories).go();
    // Preserve the scripts — null out their audio so regeneration works.
    await update(phaseTtsSegments).write(
      const PhaseTtsSegmentsCompanion(
        audioPath: Value(null),
        audioDuration: Value(null),
        error: Value(null),
        missing: Value(false),
      ),
    );
    await update(dialogTtsLines).write(
      const DialogTtsLinesCompanion(
        audioPath: Value(null),
        audioDuration: Value(null),
        error: Value(null),
        missing: Value(false),
      ),
    );
    await update(novelSegments).write(
      const NovelSegmentsCompanion(
        audioPath: Value(null),
        audioDuration: Value(null),
        audioCacheKey: Value(null),
        error: Value(null),
        missing: Value(false),
      ),
    );
    await update(subtitleCues).write(
      const SubtitleCuesCompanion(
        audioPath: Value(null),
        audioDuration: Value(null),
        error: Value(null),
        missing: Value(false),
      ),
    );
    await update(voiceAssets).write(
      const VoiceAssetsCompanion(
        refAudioPath: Value(null),
        refAudioTrimStart: Value(null),
        refAudioTrimEnd: Value(null),
      ),
    );
  });
}
