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

  Future<Map<String, String>> getSettingsWithPrefix(String prefix) async {
    final rows = await (select(
      appSettings,
    )..where((t) => t.key.like('$prefix%'))).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<int> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  Future<void> localizeStarterContent(String localeCode) async {
    final zh = localeCode.toLowerCase().startsWith('zh');
    final content = zh
        ? const _StarterContent(
            voiceName: '默认音色',
            voiceDescription: '内置起始角色',
            bankName: '默认语音库',
            bankDescription: '起始语音库',
            dialogName: '示例对话',
            phaseName: '示例旁白',
            phaseScript: '在这里输入脚本。\n\n用空行分隔段落。\n每个段落会变成一个分段。',
          )
        : const _StarterContent(
            voiceName: 'Default Voice',
            voiceDescription: 'Built-in starter character',
            bankName: 'Default Bank',
            bankDescription: 'Starter voice bank',
            dialogName: 'Sample Dialog',
            phaseName: 'Sample Narration',
            phaseScript:
                'Enter your script here.\n\nSeparate paragraphs with blank lines.\nEach paragraph becomes a segment.',
          );

    await transaction(() async {
      await customStatement(
        "UPDATE voice_assets "
        "SET name = ?, description = ? "
        "WHERE id = 'default-character' "
        "AND name IN ('Default Voice', '默认音色') "
        "AND (description IS NULL OR description IN "
        "('Built-in starter character', '内置起始角色'))",
        [content.voiceName, content.voiceDescription],
      );
      await customStatement(
        "UPDATE voice_banks "
        "SET name = ?, description = ? "
        "WHERE id = 'default-bank' "
        "AND name IN ('Default Bank', '默认语音库') "
        "AND (description IS NULL OR description IN "
        "('Starter voice bank', '起始语音库'))",
        [content.bankName, content.bankDescription],
      );
      await customStatement(
        "UPDATE dialog_tts_projects "
        "SET name = ? "
        "WHERE id = 'default-dialog-project' "
        "AND name IN ('Sample Dialog', '示例对话')",
        [content.dialogName],
      );
      await customStatement(
        "UPDATE phase_tts_projects "
        "SET name = ?, script_text = ? "
        "WHERE id = 'default-phase-project' "
        "AND name IN ('Sample Narration', '示例旁白') "
        "AND script_text IN (?, ?)",
        [
          content.phaseName,
          content.phaseScript,
          _StarterContent.enPhaseScript,
          _StarterContent.zhPhaseScript,
        ],
      );
    });
  }

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

class _StarterContent {
  static const enPhaseScript =
      'Enter your script here.\n\nSeparate paragraphs with blank lines.\nEach paragraph becomes a segment.';
  static const zhPhaseScript = '在这里输入脚本。\n\n用空行分隔段落。\n每个段落会变成一个分段。';

  final String voiceName;
  final String voiceDescription;
  final String bankName;
  final String bankDescription;
  final String dialogName;
  final String phaseName;
  final String phaseScript;

  const _StarterContent({
    required this.voiceName,
    required this.voiceDescription,
    required this.bankName,
    required this.bankDescription,
    required this.dialogName,
    required this.phaseName,
    required this.phaseScript,
  });
}
