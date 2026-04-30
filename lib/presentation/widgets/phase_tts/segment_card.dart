import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// One row in the Phase TTS segments list: index badge, voice summary,
/// status icon (generating / play / error / pending), generate button,
/// and delete.
class SegmentCard extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> bankAssets;

  /// Resolved voice asset id. Used to gate the Generate button + render the
  /// voice badge.
  final String? resolvedVoiceId;
  final bool isGenerating;
  final VoidCallback onPlay;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.bankAssets,
    required this.resolvedVoiceId,
    required this.isGenerating,
    required this.onPlay,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final assetsById = {for (final a in bankAssets) a.id: a};
    final voiceName = assetsById[resolvedVoiceId]?.name;
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
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: _VoiceSummary(voiceName: voiceName),
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
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              segment.segmentText,
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
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
        child: const Icon(
          Icons.error_rounded,
          size: 18,
          color: Colors.redAccent,
        ),
      );
    }
    return Icon(
      Icons.pending_rounded,
      size: 18,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _VoiceSummary extends StatelessWidget {
  final String? voiceName;

  const _VoiceSummary({required this.voiceName});

  @override
  Widget build(BuildContext context) {
    final hasVoice = voiceName != null && voiceName!.isNotEmpty;
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            hasVoice
                ? Icons.record_voice_over_rounded
                : Icons.voice_over_off_rounded,
            size: 15,
            color: hasVoice
                ? AppTheme.accentColor.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              voiceName ?? 'Unassigned voice',
              style: TextStyle(
                fontSize: 12,
                color: hasVoice
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.32),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
