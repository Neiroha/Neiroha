import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/dialog_tts/chat_bubble.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Scrolling, reorderable list of [ChatBubble]s for a Dialog TTS project.
///
/// Watches [playbackNotifierProvider] internally so each bubble reflects the
/// active line's progress without the parent threading playback state. The
/// per-line `Play from here` action is enabled only when the line has an
/// audio clip; the parent receives the start index and decides what to play.
class ChatListView extends ConsumerWidget {
  final AsyncValue<List<db.DialogTtsLine>> linesAsync;
  final Map<String, db.VoiceAsset> assetMap;
  final Set<String> generatingLineIds;
  final ValueChanged<db.DialogTtsLine> onPlay;
  final ValueChanged<int> onPlayFrom;
  final ValueChanged<db.DialogTtsLine>? onGenerate;
  final ValueChanged<String> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ChatListView({
    super.key,
    required this.linesAsync,
    required this.assetMap,
    required this.generatingLineIds,
    required this.onPlay,
    required this.onPlayFrom,
    required this.onGenerate,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (lines) {
        if (lines.isEmpty) return const _EmptyState();
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxBubbleWidth = constraints.maxWidth * 0.6;
            final playback = ref.watch(playbackNotifierProvider);
            return ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              buildDefaultDragHandles: false,
              itemCount: lines.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                onReorder(oldIndex, newIndex);
              },
              itemBuilder: (ctx, i) {
                final line = lines[i];
                final asset = line.voiceAssetId != null
                    ? assetMap[line.voiceAssetId]
                    : null;
                final isThisPlaying = line.audioPath != null &&
                    playback.audioPath == line.audioPath &&
                    playback.isPlaying;
                final isGenerating = generatingLineIds.contains(line.id);
                final canGenerate =
                    onGenerate != null &&
                        line.voiceAssetId != null &&
                        !isGenerating;
                return ReorderableDragStartListener(
                  key: ValueKey(line.id),
                  index: i,
                  child: ChatBubble(
                    line: line,
                    asset: asset,
                    isPlaying: isThisPlaying,
                    isGenerating: isGenerating,
                    playbackPosition:
                        isThisPlaying ? playback.position : null,
                    maxBubbleWidth: maxBubbleWidth,
                    onPlay: () => onPlay(line),
                    onPlayFrom: line.audioPath == null
                        ? null
                        : () => onPlayFrom(i),
                    onGenerate: canGenerate ? () => onGenerate!(line) : null,
                    onDelete: () => onDelete(line.id),
                  ),
                );
              },
            );
          },
        );
      },
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
          Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text('Add dialog lines below',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }
}
