import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/dialog_tts/chat_bubble.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Scrolling, reorderable list of [ChatBubble]s for a Dialog TTS project.
///
/// Each row watches only the playback fields relevant to its own audio file,
/// so the active line can update progress without rebuilding the whole list.
/// The per-line `Play from here` action is enabled only when the line has an
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
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (lines) {
        if (lines.isEmpty) return const _EmptyState();
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxBubbleWidth = constraints.maxWidth * 0.6;
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
                final isGenerating = generatingLineIds.contains(line.id);
                final canGenerate =
                    onGenerate != null &&
                    line.voiceAssetId != null &&
                    !isGenerating;
                return ReorderableDragStartListener(
                  key: ValueKey(line.id),
                  index: i,
                  child: _PlaybackAwareChatBubble(
                    line: line,
                    asset: asset,
                    isGenerating: isGenerating,
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

class _PlaybackAwareChatBubble extends ConsumerWidget {
  final db.DialogTtsLine line;
  final db.VoiceAsset? asset;
  final bool isGenerating;
  final double maxBubbleWidth;
  final VoidCallback onPlay;
  final VoidCallback? onPlayFrom;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const _PlaybackAwareChatBubble({
    required this.line,
    required this.asset,
    required this.isGenerating,
    required this.maxBubbleWidth,
    required this.onPlay,
    required this.onPlayFrom,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioPath = line.audioPath;
    final playback = ref.watch(
      playbackNotifierProvider.select((state) {
        final isThisPlaying =
            audioPath != null &&
            state.audioPath == audioPath &&
            state.isPlaying;
        return (
          isPlaying: isThisPlaying,
          position: isThisPlaying ? state.position : null,
        );
      }),
    );
    return ChatBubble(
      line: line,
      asset: asset,
      isPlaying: playback.isPlaying,
      isGenerating: isGenerating,
      playbackPosition: playback.position,
      maxBubbleWidth: maxBubbleWidth,
      onPlay: onPlay,
      onPlayFrom: onPlayFrom,
      onGenerate: onGenerate,
      onDelete: onDelete,
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
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).uiAddDialogLinesBelow,
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
