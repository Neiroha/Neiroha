import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Compact Quick TTS surface embedded in Voice Bank above the character
/// inspector. Uses the selected character (via [asset]) as the voice, so the
/// user can test the voice being edited with a single click.
class QuickTtsPanel extends ConsumerStatefulWidget {
  final db.VoiceAsset? asset;
  const QuickTtsPanel({super.key, required this.asset});

  @override
  ConsumerState<QuickTtsPanel> createState() => _QuickTtsPanelState();
}

class _QuickTtsPanelState extends ConsumerState<QuickTtsPanel> {
  final _textController = TextEditingController();
  bool _generating = false;
  bool _deleteAllConfirm = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final historyAsync = ref.watch(quickTtsHistoryStreamProvider);
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);

    if (asset == null) {
      return _buildEmptyState();
    }

    // Filter history to the currently-selected character so the test surface
    // stays focused on the voice being edited.
    final filteredHistory = historyAsync.whenData(
      (list) => list.where((h) => h.voiceAssetId == asset.id).toList(),
    );

    return Column(
      children: [
        _buildHeader(asset, filteredHistory),
        Expanded(child: _buildHistory(filteredHistory, assetsAsync)),
        _buildGenerateBar(asset),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded,
              size: 40, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 10),
          Text('Select a character to quick-test',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    db.VoiceAsset asset,
    AsyncValue<List<db.QuickTtsHistory>> historyAsync,
  ) {
    final hasHistory = (historyAsync.valueOrNull ?? []).isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded,
              size: 16, color: AppTheme.accentColor),
          const SizedBox(width: 8),
          Text('QUICK TEST',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(asset.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4))),
          ),
          const Spacer(),
          if (hasHistory)
            _deleteAllConfirm
                ? TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(databaseProvider)
                          .clearQuickTtsHistoryForAsset(asset.id);
                      if (mounted) {
                        setState(() => _deleteAllConfirm = false);
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 14),
                    label: const Text('Confirm',
                        style: TextStyle(fontSize: 11)),
                  )
                : IconButton(
                    tooltip: 'Clear history for this character',
                    onPressed: () =>
                        setState(() => _deleteAllConfirm = true),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.delete_sweep_rounded,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
        ],
      ),
    );
  }

  Widget _buildHistory(
    AsyncValue<List<db.QuickTtsHistory>> historyAsync,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
  ) {
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded,
                    size: 36, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                Text('Type below to test this voice',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: history.length,
          itemBuilder: (ctx, i) {
            final entry = history[i];
            final playback = ref.watch(playbackNotifierProvider);
            final isPlaying = entry.audioPath != null &&
                playback.audioPath == entry.audioPath &&
                playback.isPlaying;
            final hasAudio = entry.audioPath != null;
            final hasError = entry.error != null;

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(entry.inputText,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.8)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (hasError)
                          Tooltip(
                            message: entry.error!,
                            child: const Icon(Icons.error_rounded,
                                color: Colors.redAccent, size: 14),
                          ),
                        IconButton(
                          onPressed: () async {
                            if (entry.audioPath != null) {
                              final file = File(entry.audioPath!);
                              if (file.existsSync()) {
                                await file.delete();
                              }
                            }
                            await ref
                                .read(databaseProvider)
                                .deleteQuickTtsHistory(entry.id);
                          },
                          icon: Icon(Icons.close_rounded,
                              size: 12,
                              color:
                                  Colors.white.withValues(alpha: 0.3)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    if (hasAudio) ...[
                      const SizedBox(height: 6),
                      _buildAudioRow(entry, isPlaying),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioRow(db.QuickTtsHistory entry, bool isPlaying) {
    String durationText = '--:--';
    if (entry.audioDuration != null) {
      final totalSecs = entry.audioDuration!;
      final mins = (totalSecs / 60).floor();
      final secs = (totalSecs % 60).floor();
      durationText =
          '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final notifier = ref.read(playbackNotifierProvider.notifier);
            if (isPlaying) {
              await notifier.stop();
            } else {
              await notifier.load(
                entry.audioPath!,
                entry.inputText,
                subtitle: entry.voiceName,
              );
            }
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(24, (i) {
                final progress = i / 24.0;
                final wave1 = math.sin(progress * math.pi * 4).abs();
                final wave2 = math.sin(progress * math.pi * 7 + 1.2).abs();
                final wave3 = math.sin(progress * math.pi * 2.5 + 0.5).abs();
                final h =
                    3.0 + (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25) * 14.0;
                return Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      height: h,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppTheme.accentColor.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          durationText,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: isPlaying
                ? AppTheme.accentColor
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateBar(db.VoiceAsset asset) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type something to test...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton.filled(
                onPressed: _textController.text.isEmpty
                    ? null
                    : () => _generate(asset),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  disabledBackgroundColor:
                      AppTheme.accentColor.withValues(alpha: 0.3),
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(db.VoiceAsset asset) async {
    final providers =
        ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final provider =
        providers.where((p) => p.id == asset.providerId).firstOrNull;
    if (provider == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Provider not found for this character')));
      }
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _generating = true);
    if (_deleteAllConfirm) setState(() => _deleteAllConfirm = false);
    final database = ref.read(databaseProvider);
    final entryId = const Uuid().v4();

    try {
      final adapter = createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(TtsRequest(
        text: text,
        voice: asset.presetVoiceName ?? asset.name,
        speed: asset.speed,
        textLang: provider.adapterType == 'gptSovits' ? asset.modelName : null,
        presetVoiceName: asset.presetVoiceName,
        voiceInstruction: asset.voiceInstruction,
        refAudioPath: asset.refAudioPath,
        promptText: asset.promptText,
        promptLang: asset.promptLang,
      ));

      final dir = await getApplicationSupportDirectory();
      final outDir = Directory(p.join(dir.path, 'quick_tts'));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final ext = result.contentType.contains('wav') ? 'wav' : 'mp3';
      final filePath = p.join(
          outDir.path, '${DateTime.now().millisecondsSinceEpoch}.$ext');
      await File(filePath).writeAsBytes(result.audioBytes);

      await database.insertQuickTtsHistory(
        db.QuickTtsHistoriesCompanion(
          id: Value(entryId),
          voiceAssetId: Value(asset.id),
          voiceName: Value(asset.name),
          inputText: Value(text),
          audioPath: Value(filePath),
          createdAt: Value(DateTime.now()),
        ),
      );

      final player = ref.read(audioPlayerProvider);
      await ref.read(playbackNotifierProvider.notifier).load(
            filePath,
            text,
            subtitle: asset.name,
          );
      player.onDurationChanged.first.then((d) async {
        final secs = d.inMilliseconds / 1000.0;
        await database.updateQuickTtsHistoryDuration(entryId, secs);
      }).catchError((_) {});
    } catch (e) {
      await database.insertQuickTtsHistory(
        db.QuickTtsHistoriesCompanion(
          id: Value(entryId),
          voiceAssetId: Value(asset.id),
          voiceName: Value(asset.name),
          inputText: Value(text),
          error: Value(e.toString()),
          createdAt: Value(DateTime.now()),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}
