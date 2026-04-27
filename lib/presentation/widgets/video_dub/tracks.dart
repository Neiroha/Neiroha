import 'package:drift/drift.dart' show Value;
import 'package:neiroha/data/database/app_database.dart' as db;

/// Track addressing inside `TimelineClips` for video-dub projects.
/// Simplified 1V3A layout (no image/V2 lane, no PR-class compositing):
///
///   V1 -> laneIndex -1: the single dubbed video. Only one clip allowed.
///   A1 -> laneIndex  1: V1's original audio, linked on import.
///   A2 -> virtual lane: TTS cues sourced directly from `SubtitleCues`.
///   A3 -> laneIndex  3: free-form imported audio.
///
/// Lane index 2 is reserved for A2 if cues ever migrate into `TimelineClips`.
class DubLanes {
  static const int v1 = -1;
  static const int a1 = 1;
  static const int a3 = 3;
}

/// Which import bucket a file should be placed in.
enum DubImportKind { video, audio }

/// Resolve an import kind to the primary lane and source type.
///
/// `DubImportKind.video` yields the V1 entry; the caller is responsible for
/// also inserting the linked A1 sibling.
({int lane, String sourceType}) laneAndSourceForImport(DubImportKind kind) {
  switch (kind) {
    case DubImportKind.video:
      return (lane: DubLanes.v1, sourceType: 'video');
    case DubImportKind.audio:
      return (lane: DubLanes.a3, sourceType: 'imported');
  }
}

/// Companion factory so callers do not need to import drift's `Value`.
///
/// [linkGroupId] pairs this clip with a sibling, such as V1 plus its A1 audio.
db.TimelineClipsCompanion makeDubClipCompanion({
  required String id,
  required String projectId,
  required int lane,
  required int startTimeMs,
  required String sourceType,
  required String audioPath,
  required String label,
  double? durationSec,
  String? linkGroupId,
}) {
  return db.TimelineClipsCompanion(
    id: Value(id),
    projectId: Value(projectId),
    projectType: const Value('videodub'),
    laneIndex: Value(lane),
    startTimeMs: Value(startTimeMs),
    durationSec: Value(durationSec),
    audioPath: Value(audioPath),
    sourceType: Value(sourceType),
    label: Value(label),
    linkGroupId: Value(linkGroupId),
  );
}
