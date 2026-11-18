import 'package:drift/drift.dart';

import '../app_database.dart';
import 'schema_editor.dart';

/// Some releases stamped the current version before restoring missing parts.
/// Keep their add-only repair separate from new migrations.
Future<void> repairLegacySchema(AppDatabase db, Migrator m) async {
  final editor = SchemaEditor(db);
  for (final table in db.allTables) {
    if (!await editor.tableExists(table.actualTableName)) {
      await m.createTable(table);
    }
  }
  for (final (table, column) in <(TableInfo, GeneratedColumn)>[
    (db.ttsProviders, db.ttsProviders.maxConcurrency),
    (db.ttsProviders, db.ttsProviders.requestsPerMinute),
    (db.ttsProviders, db.ttsProviders.requestsPerDay),
    (db.ttsProviders, db.ttsProviders.tokensPerMinute),
    (db.ttsProviders, db.ttsProviders.tokensPerDay),
    (db.voiceBanks, db.voiceBanks.loudnessTargetLufs),
    (db.voiceAssets, db.voiceAssets.loudnessOffsetDb),
    (db.audioTracks, db.audioTracks.missing),
    (db.voiceAssets, db.voiceAssets.folderSlug),
    (db.quickTtsHistories, db.quickTtsHistories.missing),
    (db.phaseTtsProjects, db.phaseTtsProjects.folderSlug),
    (db.phaseTtsSegments, db.phaseTtsSegments.speakerLabel),
    (db.phaseTtsSegments, db.phaseTtsSegments.voiceAssetId),
    (db.phaseTtsSegments, db.phaseTtsSegments.audioPath),
    (db.phaseTtsSegments, db.phaseTtsSegments.audioDuration),
    (db.phaseTtsSegments, db.phaseTtsSegments.error),
    (db.phaseTtsSegments, db.phaseTtsSegments.missing),
    (db.novelProjects, db.novelProjects.narratorVoiceAssetId),
    (db.novelProjects, db.novelProjects.dialogueVoiceAssetId),
    (db.novelProjects, db.novelProjects.readerTheme),
    (db.novelProjects, db.novelProjects.fontSize),
    (db.novelProjects, db.novelProjects.lineHeight),
    (db.novelProjects, db.novelProjects.autoTurnPage),
    (db.novelProjects, db.novelProjects.autoAdvanceChapters),
    (db.novelProjects, db.novelProjects.autoSliceLongSegments),
    (db.novelProjects, db.novelProjects.sliceOnlyAtPunctuation),
    (db.novelProjects, db.novelProjects.maxSliceChars),
    (db.novelProjects, db.novelProjects.prefetchSegments),
    (db.novelProjects, db.novelProjects.playbackGapSeconds),
    (db.novelProjects, db.novelProjects.overwriteCacheWhilePlaying),
    (db.novelProjects, db.novelProjects.skipPunctuationOnlySegments),
    (db.novelProjects, db.novelProjects.cacheCurrentColor),
    (db.novelProjects, db.novelProjects.cacheStaleColor),
    (db.novelProjects, db.novelProjects.cacheHighlightOpacity),
    (db.novelProjects, db.novelProjects.currentGlobalIndex),
    (db.novelProjects, db.novelProjects.folderSlug),
    (db.novelChapters, db.novelChapters.sourcePath),
    (db.novelChapters, db.novelChapters.rawText),
    (db.novelSegments, db.novelSegments.segmentType),
    (db.novelSegments, db.novelSegments.audioPath),
    (db.novelSegments, db.novelSegments.audioDuration),
    (db.novelSegments, db.novelSegments.audioCacheKey),
    (db.novelSegments, db.novelSegments.error),
    (db.novelSegments, db.novelSegments.missing),
    (db.dialogTtsProjects, db.dialogTtsProjects.folderSlug),
    (db.dialogTtsLines, db.dialogTtsLines.voiceAssetId),
    (db.dialogTtsLines, db.dialogTtsLines.audioPath),
    (db.dialogTtsLines, db.dialogTtsLines.audioDuration),
    (db.dialogTtsLines, db.dialogTtsLines.error),
    (db.dialogTtsLines, db.dialogTtsLines.missing),
    (db.videoDubProjects, db.videoDubProjects.videoPath),
    (db.videoDubProjects, db.videoDubProjects.videoDurationSec),
    (db.videoDubProjects, db.videoDubProjects.folderSlug),
    (db.subtitleCues, db.subtitleCues.voiceAssetId),
    (db.subtitleCues, db.subtitleCues.audioPath),
    (db.subtitleCues, db.subtitleCues.audioDuration),
    (db.subtitleCues, db.subtitleCues.error),
    (db.subtitleCues, db.subtitleCues.missing),
    (db.timelineClips, db.timelineClips.laneIndex),
    (db.timelineClips, db.timelineClips.startTimeMs),
    (db.timelineClips, db.timelineClips.durationSec),
    (db.timelineClips, db.timelineClips.sourceType),
    (db.timelineClips, db.timelineClips.sourceLineId),
    (db.timelineClips, db.timelineClips.label),
    (db.timelineClips, db.timelineClips.missing),
    (db.timelineClips, db.timelineClips.linkGroupId),
  ]) {
    if (!(await editor.columns(table.actualTableName)).contains(column.name)) {
      await m.addColumn(table, column);
      editor.forgetColumns(table.actualTableName);
    }
  }
}
