import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/phase_tts/segment_card.dart';

/// Right-pane segments list for the Phase TTS editor. Shows the SEGMENTS
/// section header, the empty-state hint, or a [SegmentCard] per segment.
///
/// All side effects bubble up through callbacks — the parent owns the
/// playback notifier and database writes.
class SegmentPanel extends StatelessWidget {
  final AsyncValue<List<db.PhaseTtsSegment>> segmentsAsync;
  final List<db.VoiceAsset> bankAssets;
  final String? Function(db.PhaseTtsSegment segment) resolveVoice;
  final Set<String> generatingSegmentIds;
  final void Function(db.PhaseTtsSegment segment, int index) onPlay;
  final void Function(db.PhaseTtsSegment segment)? onGenerate;
  final ValueChanged<String> onDelete;

  const SegmentPanel({
    super.key,
    required this.segmentsAsync,
    required this.bankAssets,
    required this.resolveVoice,
    required this.generatingSegmentIds,
    required this.onPlay,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'SEGMENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: segmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (segments) {
              if (segments.isEmpty) return const _EmptyState();
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: segments.length,
                itemBuilder: (ctx, i) {
                  final seg = segments[i];
                  final isBusy = generatingSegmentIds.contains(seg.id);
                  final voiceId = resolveVoice(seg);
                  return SegmentCard(
                    segment: seg,
                    index: i,
                    bankAssets: bankAssets,
                    resolvedVoiceId: voiceId,
                    isGenerating: isBusy,
                    onPlay: () => onPlay(seg, i),
                    onGenerate: voiceId == null || isBusy || onGenerate == null
                        ? null
                        : () => onGenerate!(seg),
                    onDelete: () => onDelete(seg.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.segment_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Text(
            'Click "Auto Split" to create\nsegments from script',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
