import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/story_track_editor.dart'
    show TimelineDragButton, TimelineDropPayload;

/// One row in the Phase TTS segments list: index badge, voice dropdown,
/// status icon (generating / play / error / pending), generate button,
/// timeline-drag handle, and delete.
///
/// `onGenerate` is null while the row is busy or has no voice picked.
/// `onAddToTimeline` is null until audio exists.
class SegmentCard extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> bankAssets;
  final bool isGenerating;
  final VoidCallback onPlay;
  final VoidCallback? onGenerate;
  final VoidCallback? onAddToTimeline;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onDelete;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.bankAssets,
    required this.isGenerating,
    required this.onPlay,
    required this.onGenerate,
    required this.onAddToTimeline,
    required this.onVoiceChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Voice',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      isExpanded: true,
                      initialValue:
                          bankAssets.any((a) => a.id == segment.voiceAssetId)
                              ? segment.voiceAssetId
                              : null,
                      items: bankAssets
                          .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: onVoiceChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _buildStatus(),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    segment.audioPath != null
                        ? Icons.refresh_rounded
                        : Icons.auto_awesome_rounded,
                    size: 16,
                    color: onGenerate == null
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppTheme.accentColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: segment.audioPath != null
                      ? 'Regenerate'
                      : 'Generate',
                  onPressed: onGenerate,
                ),
                const SizedBox(width: 4),
                TimelineDragButton(
                  enabled: onAddToTimeline != null,
                  payload: segment.audioPath == null
                      ? null
                      : TimelineDropPayload(
                          audioPath: segment.audioPath!,
                          label: bankAssets
                                  .where((a) => a.id == segment.voiceAssetId)
                                  .firstOrNull
                                  ?.name ??
                              'Segment ${index + 1}',
                          durationSec: segment.audioDuration,
                          sourceLineId: segment.id,
                        ),
                  onTap: onAddToTimeline,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(segment.segmentText,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (isGenerating) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (segment.audioPath != null) {
      return IconButton(
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPlay,
      );
    }
    if (segment.error != null) {
      return Tooltip(
        message: segment.error!,
        child: const Icon(Icons.error_rounded,
            size: 18, color: Colors.redAccent),
      );
    }
    return Icon(Icons.pending_rounded,
        size: 18, color: Colors.white.withValues(alpha: 0.2));
  }
}
