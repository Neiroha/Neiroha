import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/synthesis/sentence_preview_service.dart';
import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

export 'package:neiroha/data/services/synthesis/sentence_preview_service.dart'
    show SentenceProjectKind;

final _sentencePreviewServiceProvider = Provider(
  (ref) => SentencePreviewService(
    ref.watch(databaseProvider),
    ref.watch(storageServiceProvider),
    ref.watch(synthesisServiceProvider),
    ref.watch(autoLoudnessServiceProvider),
  ),
);

class LiveSentencePreviewButton extends ConsumerStatefulWidget {
  factory LiveSentencePreviewButton.phase(
    db.PhaseTtsSegment segment, {
    bool disabled = false,
  }) => LiveSentencePreviewButton(
    kind: SentenceProjectKind.phase,
    projectId: segment.projectId,
    id: segment.id,
    text: segment.segmentText,
    voiceId: segment.voiceAssetId,
    audioPath: segment.missing ? null : segment.audioPath,
    disabled: disabled,
  );
  const LiveSentencePreviewButton({
    super.key,
    required this.kind,
    required this.projectId,
    required this.id,
    required this.text,
    this.voiceId,
    this.audioPath,
    this.beforePlay,
    this.disabled = false,
  });
  final SentenceProjectKind kind;
  final String projectId;
  final String id;
  final String text;
  final String? voiceId;
  final String? audioPath;
  final Future<void> Function()? beforePlay;
  final bool disabled;
  @override
  ConsumerState<LiveSentencePreviewButton> createState() =>
      _LiveSentencePreviewButtonState();
}

class _LiveSentencePreviewButtonState
    extends ConsumerState<LiveSentencePreviewButton> {
  TtsCancelToken? _cancellation;
  String get _source =>
      'sentence.preview.${widget.kind.name}.${widget.projectId}.${widget.id}';
  @override
  void didUpdateWidget(covariant LiveSentencePreviewButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.voiceId != widget.voiceId ||
        oldWidget.id != widget.id) {
      _cancellation?.cancel();
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final playback = ref.watch(playbackNotifierProvider);
    final playing =
        playback.sourceTag == _source &&
        (playback.isPlaying || playback.isStreaming);
    return IconButton(
      tooltip: playing ? l.uiStopSynthesis : l.uiLiveSentencePreview,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      icon: Icon(
        playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
        size: 20,
      ),
      onPressed: widget.disabled || widget.voiceId == null
          ? null
          : () async {
              final notifier = ref.read(playbackNotifierProvider.notifier);
              if (playing ||
                  (_cancellation != null && !playback.generationComplete)) {
                _cancellation?.cancel();
                await notifier.stopIfSourceTag(_source);
                return;
              }
              _cancellation?.cancel();
              final token = TtsCancelToken();
              _cancellation = token;
              try {
                await widget.beforePlay?.call();
                token.throwIfCancelled();
                if (widget.audioPath != null &&
                    File(widget.audioPath!).existsSync()) {
                  await notifier.load(
                    widget.audioPath!,
                    widget.text,
                    sourceTag: _source,
                  );
                  return;
                }
                await notifier.playSynthesis(
                  title: widget.text,
                  sourceTag: _source,
                  cancellation: token,
                  generate: (sink) => ref
                      .read(_sentencePreviewServiceProvider)
                      .generate(
                        kind: widget.kind,
                        projectId: widget.projectId,
                        id: widget.id,
                        cancellation: token,
                        sink: sink,
                      ),
                );
              } on TtsCancelledException {
                /* No incomplete project audio is saved. */
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              } finally {
                if (mounted &&
                    identical(_cancellation, token) &&
                    !ref.read(playbackNotifierProvider).isStreaming) {
                  _cancellation = null;
                }
              }
            },
    );
  }
}
