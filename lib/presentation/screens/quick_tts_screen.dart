import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:q_vox_lab/data/adapters/tts_adapter.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

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
  final _player = AudioPlayer();
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final historyAsync = ref.watch(quickTtsHistoryStreamProvider);

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 280, child: _buildVoiceSelector(assetsAsync)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildHistory(historyAsync, assetsAsync)),
            ],
          ),
        ),
        _buildGenerateBar(context, assetsAsync),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                        Text('No voices yet',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.4))),
                        const SizedBox(height: 8),
                        Text('Create a Voice Character first',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.3))),
                      ],
                    ),
                  ),
                );
              }
              final enabled = assets.where((a) => a.enabled).toList();
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: enabled.length,
                itemBuilder: (context, index) {
                  final a = enabled[index];
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
            final entry = history[i]; // already sorted newest first
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.accentColor.withValues(alpha: 0.2),
                      child: Text(
                          entry.voiceName.isNotEmpty
                              ? entry.voiceName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.voiceName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(entry.inputText,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white
                                      .withValues(alpha: 0.7)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (entry.error != null)
                      Tooltip(
                        message: entry.error!,
                        child: const Icon(Icons.error_rounded,
                            color: Colors.redAccent, size: 20),
                      )
                    else if (entry.audioPath != null)
                      IconButton(
                        onPressed: () async {
                          if (_playingId == entry.id) {
                            await _player.stop();
                            setState(() => _playingId = null);
                          } else {
                            await _player
                                .play(DeviceFileSource(entry.audioPath!));
                            setState(() => _playingId = entry.id);
                          }
                        },
                        icon: Icon(
                          _playingId == entry.id
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                        tooltip: 'Play',
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final database = ref.read(databaseProvider);
    final entryId = const Uuid().v4();

    try {
      final adapter =
          createAdapter(provider, modelName: asset.modelName);
      final result = await adapter.synthesize(TtsRequest(
        text: text,
        voice: asset.presetVoiceName ?? asset.name,
        speed: asset.speed,
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

      // Persist to DB
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

      // Auto-play
      await _player.play(DeviceFileSource(filePath));
      setState(() => _playingId = entryId);
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
