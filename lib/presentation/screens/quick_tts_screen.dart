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
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Quick TTS — select a voice character, type text, generate & play audio.
/// History is persisted to SQLite.
class QuickTtsScreen extends ConsumerStatefulWidget {
  const QuickTtsScreen({super.key});

  @override
  ConsumerState<QuickTtsScreen> createState() => _QuickTtsScreenState();
}

class _QuickTtsScreenState extends ConsumerState<QuickTtsScreen> {
  final _textController = TextEditingController();
  String? _selectedVoiceId;
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
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final historyAsync = ref.watch(quickTtsHistoryStreamProvider);
    final activeBankAsync = ref.watch(activeBankStreamProvider);

    // Build the list of voices from the active bank only
    final activeBankVoices = activeBankAsync.when<AsyncValue<List<db.VoiceAsset>>>(
      loading: () => const AsyncValue.loading(),
      error: (e, s) => AsyncValue.error(e, s),
      data: (activeBank) {
        if (activeBank == null) {
          return const AsyncValue.data([]);
        }
        final membersAsync = ref.watch(bankMembersStreamProvider(activeBank.id));
        return membersAsync.when(
          loading: () => const AsyncValue.loading(),
          error: (e, s) => AsyncValue.error(e, s),
          data: (members) {
            final allAssets = assetsAsync.valueOrNull ?? [];
            final memberAssetIds = members.map((m) => m.voiceAssetId).toSet();
            final bankAssets = allAssets
                .where((a) => memberAssetIds.contains(a.id) && a.enabled)
                .toList();
            return AsyncValue.data(bankAssets);
          },
        );
      },
    );

    // Auto-select first voice if none selected
    final bankVoices = activeBankVoices.valueOrNull;
    if (bankVoices != null && bankVoices.isNotEmpty && _selectedVoiceId == null) {
      _selectedVoiceId = bankVoices.first.id;
    }

    return Column(
      children: [
        _buildHeader(context, historyAsync),
        Expanded(
          child: ResizableSplitPane(
            initialLeftFraction: 0.3,
            left: _buildVoiceSelector(activeBankVoices),
            rightBuilder: (_) => _buildHistory(historyAsync, assetsAsync),
          ),
        ),
        _buildGenerateBar(context, assetsAsync),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<List<db.QuickTtsHistory>> historyAsync) {
    final hasHistory = (historyAsync.valueOrNull ?? []).isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Quick TTS',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Test voices with short text',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          if (hasHistory)
            _deleteAllConfirm
                ? FilledButton.icon(
                    onPressed: () async {
                      await ref.read(databaseProvider).clearQuickTtsHistory();
                      setState(() => _deleteAllConfirm = false);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Confirm Delete All'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => setState(() => _deleteAllConfirm = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Delete All'),
                  ),
        ],
      ),
    );
  }

  Widget _buildVoiceSelector(AsyncValue<List<db.VoiceAsset>> assetsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('VOICES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
        ),
        Expanded(
          child: assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assets) {
              if (assets.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('No voices in active bank',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.4))),
                        const SizedBox(height: 8),
                        Text('Activate a Voice Bank with characters',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.3))),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: assets.length,
                itemBuilder: (context, index) {
                  final a = assets[index];
                  final isSelected = _selectedVoiceId == a.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? AppTheme.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () =>
                            setState(() => _selectedVoiceId = a.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              _VoiceAvatar(asset: a, isSelected: isSelected),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(a.name,
                                        style:
                                            const TextStyle(fontSize: 14)),
                                    Text(
                                      _modeLabel(a.taskMode),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withValues(alpha: 0.4)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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
                    size: 64, color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 12),
                Text('Generation history will appear here',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
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
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Character name + delete button
                    Row(
                      children: [
                        _historyAvatar(entry, assetsAsync),
                        const SizedBox(width: 8),
                        Text(entry.voiceName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (hasError)
                          Tooltip(
                            message: entry.error!,
                            child: const Icon(Icons.error_rounded,
                                color: Colors.redAccent, size: 16),
                          ),
                        IconButton(
                          onPressed: () async {
                            // Delete audio file if exists
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
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.3)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Line 2: Text content
                    Text(entry.inputText,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    // Line 3: Waveform + time (if audio exists)
                    if (hasAudio) ...[
                      const SizedBox(height: 8),
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
    // Format duration as mm:ss
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
        // Play/stop button
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isPlaying
                  ? AppTheme.accentColor
                  : AppTheme.accentColor.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform bars — 30% width
        SizedBox(
          width: 120,
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(20, (i) {
              final progress = i / 20.0;
              final wave1 = math.sin(progress * math.pi * 4).abs();
              final wave2 = math.sin(progress * math.pi * 7 + 1.2).abs();
              final wave3 = math.sin(progress * math.pi * 2.5 + 0.5).abs();
              final h =
                  3.0 + (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25) * 18.0;
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
        const SizedBox(width: 8),
        // Duration
        Text(
          durationText,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: isPlaying
                ? AppTheme.accentColor
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _historyAvatar(
    db.QuickTtsHistory entry,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
  ) {
    final asset = assetsAsync.valueOrNull
        ?.where((a) => a.id == entry.voiceAssetId)
        .firstOrNull;
    if (asset != null &&
        asset.avatarPath != null &&
        File(asset.avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: FileImage(File(asset.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
      child: Text(
        entry.voiceName.isNotEmpty ? entry.voiceName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildGenerateBar(
    BuildContext context,
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type something to synthesize...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
              ),
            ),
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                onPressed: _selectedVoiceId == null ||
                        _textController.text.isEmpty
                    ? null
                    : () => _generate(assetsAsync),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  disabledBackgroundColor:
                      AppTheme.accentColor.withValues(alpha: 0.3),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(
    AsyncValue<List<db.VoiceAsset>> assetsAsync,
  ) async {
    final assets = assetsAsync.valueOrNull ?? [];
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final asset =
        assets.where((a) => a.id == _selectedVoiceId).firstOrNull;
    if (asset == null) return;
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
    // Reset delete-all confirm state
    if (_deleteAllConfirm) setState(() => _deleteAllConfirm = false);
    final database = ref.read(databaseProvider);
    final entryId = const Uuid().v4();

    try {
      final adapter =
          createAdapter(provider, modelName: asset.modelName);
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

      // Save to temp file
      final dir = await getApplicationSupportDirectory();
      final outDir = Directory(p.join(dir.path, 'quick_tts'));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final ext =
          result.contentType.contains('wav') ? 'wav' : 'mp3';
      final filePath = p.join(
          outDir.path, '${DateTime.now().millisecondsSinceEpoch}.$ext');
      await File(filePath).writeAsBytes(result.audioBytes);

      // Persist to DB (duration filled in lazily after playback starts)
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

      // Auto-play via global notifier; capture duration from the shared player.
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
      // Persist error to DB
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

class _VoiceAvatar extends StatelessWidget {
  final db.VoiceAsset asset;
  final bool isSelected;
  const _VoiceAvatar({required this.asset, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    if (asset.avatarPath != null && File(asset.avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: FileImage(File(asset.avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor:
          isSelected ? AppTheme.accentColor : const Color(0xFF2A2A36),
      child: Text(
        asset.name.isNotEmpty ? asset.name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
    );
  }
}

String _modeLabel(String mode) => switch (mode) {
      'cloneWithPrompt' => 'Voice Clone',
      'presetVoice' => 'Preset Voice',
      'voiceDesign' => 'Voice Design',
      _ => mode,
    };
