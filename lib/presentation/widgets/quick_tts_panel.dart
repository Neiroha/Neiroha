import 'package:neiroha/domain/synthesis/tts_cancellation.dart';
import 'quick_tts/history_list.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/speech_http_response.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/actions/browser_speech_message.dart';
import 'package:neiroha/presentation/actions/voice_health_warning.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/browser_quick_tts.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/providers/quick_tts_preferences.dart';
import 'package:neiroha/providers/session_audio_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
  TtsCancelToken? _cancellation;
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
    _cancellation?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QuickTtsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset?.id != widget.asset?.id) _cancellation?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final historyAsync = kIsWeb
        ? AsyncData(ref.watch(sessionAudioProvider))
        : ref.watch(quickTtsHistoryStreamProvider);

    if (asset == null) {
      return _buildEmptyState();
    }
    final platform = ref.watch(platformCapabilitiesProvider);
    final providers = ref.watch(ttsProvidersStreamProvider);
    final provider = providers.value
        ?.where((provider) => provider.id == asset.providerId)
        .firstOrNull;
    final l10n = AppLocalizations.of(context);
    final block = !platform.isWeb || provider == null
        ? null
        : browserSpeechBlockForVoice(provider, asset);
    final unavailable = block != null
        ? browserSpeechMessage(l10n, block)
        : provider == null && !providers.isLoading
        ? l10n.uiProviderNotFoundForThisCharacter
        : null;
    final canStream = supportsQuickTtsStreaming(provider, asset, platform);
    final preference = canStream
        ? ref.watch(quickTtsStreamingProvider(asset.id))
        : const AsyncData(false);
    final stream = preference.value ?? canStream;
    final canGenerate =
        provider != null && block == null && !preference.isLoading;

    // Filter history to the currently-selected character so the test surface
    // stays focused on the voice being edited.
    final filteredHistory = historyAsync.whenData(
      (list) => list.where((h) => h.voiceAssetId == asset.id).toList(),
    );

    return Column(
      children: [
        _buildHeader(
          asset,
          filteredHistory,
          mode: canGenerate
              ? (stream
                    ? l10n.quickTtsStreamPlayback
                    : l10n.quickTtsFullPlayback)
              : null,
        ),
        Expanded(
          child: QuickTtsHistoryList(
            historyAsync: filteredHistory,
            onSave: _saveEntryAsVoiceAsset,
          ),
        ),
        const PersistentAudioBar(
          onlyForSourceTag: voiceBankQuickTestPlaybackSource,
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              l10n.webSessionAudio,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (unavailable != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              unavailable,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        _buildGenerateBar(canGenerate ? () => _generate(asset, stream) : null),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).uiSelectACharacterToQuickTest,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    db.VoiceAsset asset,
    AsyncValue<List<db.QuickTtsHistory>> historyAsync, {
    required String? mode,
  }) {
    final hasHistory = (historyAsync.value ?? []).isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, size: 16, color: AppTheme.accentColor),
          SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).uiQUICKTEST,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              asset.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          if (mode != null)
            Expanded(
              flex: 2,
              child: Text(
                mode,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          if (hasHistory)
            _deleteAllConfirm
                ? TextButton.icon(
                    onPressed: () async {
                      if (kIsWeb) {
                        final history = ref.read(sessionAudioProvider.notifier);
                        final playback = ref.read(
                          playbackNotifierProvider.notifier,
                        );
                        history.clearVoice(asset.id);
                        await playback.stopIfSourceTag(
                          voiceBankQuickTestPlaybackSource,
                        );
                      } else {
                        await ref
                            .read(databaseProvider)
                            .clearQuickTtsHistoryForAsset(asset.id);
                      }
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
                    label: Text(
                      AppLocalizations.of(context).uiConfirm,
                      style: TextStyle(fontSize: 11),
                    ),
                  )
                : IconButton(
                    tooltip: AppLocalizations.of(
                      context,
                    ).uiClearHistoryForThisCharacter,
                    onPressed: () => setState(() => _deleteAllConfirm = true),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
        ],
      ),
    );
  }

  Future<void> _saveEntryAsVoiceAsset(db.QuickTtsHistory entry) async {
    final src = entry.audioPath;
    if (src == null || !File(src).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiAudioFileIsMissingCannotSave,
            ),
          ),
        );
      }
      return;
    }
    final asset = widget.asset;
    final database = ref.read(databaseProvider);
    try {
      final vaDir = await PathService.instance.voiceCharacterRefDir();
      final trackId = const Uuid().v4();
      final ext = p.extension(src).isEmpty ? '.wav' : p.extension(src);

      // Trim the input text for the asset name so long prompts don't create
      // unusable labels.
      final raw = entry.inputText.trim();
      final shortText = raw.length > 24 ? '${raw.substring(0, 24)}…' : raw;
      final assetName = shortText.isEmpty
          ? '${entry.voiceName} quicktest'
          : '${entry.voiceName} · $shortText';

      final fileBase = shortText.isEmpty
          ? '${entry.voiceName}_${PathService.formatTimestamp()}'
          : '${entry.voiceName}_${raw.length > 24 ? raw.substring(0, 24) : raw}_${PathService.formatTimestamp()}';
      final dest = PathService.dedupeFilename(
        vaDir,
        PathService.sanitizeSegment(fileBase, fallback: 'quicktest'),
        ext,
      );
      await File(src).copy(dest);

      await database.insertAudioTrack(
        db.AudioTracksCompanion(
          id: Value(trackId),
          name: Value(assetName),
          description: Value('Saved from Quick Test'),
          audioPath: Value(dest),
          refText: Value(raw.isEmpty ? null : raw),
          refLang: Value(asset?.promptLang),
          durationSec: Value(entry.audioDuration),
          sourceType: const Value('quickTts'),
          createdAt: Value(DateTime.now()),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiSavedToVoiceAssets(assetName),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiFailedToSave(e)),
          ),
        );
      }
    }
  }

  Widget _buildGenerateBar(VoidCallback? generate) {
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
                hintText: AppLocalizations.of(context).uiTypeSomethingToTest,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          if (_generating)
            IconButton(
              tooltip: AppLocalizations.of(context).uiStopSynthesis,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () {
                _cancellation?.cancel();
                ref
                    .read(playbackNotifierProvider.notifier)
                    .stopIfSourceTag(voiceBankQuickTestPlaybackSource);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton.filled(
                tooltip: AppLocalizations.of(context).uiGenerate,
                onPressed: _textController.text.isEmpty ? null : generate,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  disabledBackgroundColor: AppTheme.accentColor.withValues(
                    alpha: 0.3,
                  ),
                  minimumSize: const Size(32, 32),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(db.VoiceAsset asset, bool stream) async {
    final provider = ref
        .read(ttsProvidersStreamProvider)
        .value
        ?.where((provider) => provider.id == asset.providerId)
        .firstOrNull;
    if (provider == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final block = kIsWeb ? browserSpeechBlockForVoice(provider, asset) : null;
    if (block != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(browserSpeechMessage(l10n, block))),
      );
      return;
    }

    warnIfVoiceHealthFailedOnce(context: context, ref: ref, asset: asset);
    setState(() => _generating = true);
    if (_deleteAllConfirm) setState(() => _deleteAllConfirm = false);
    final entryId = const Uuid().v4();

    final cancellation = TtsCancelToken();
    _cancellation = cancellation;
    try {
      if (kIsWeb) {
        await generateBrowserQuickTts(
          ref,
          entryId: entryId,
          provider: provider,
          voice: asset,
          text: text,
          cancellation: cancellation,
          stream: stream,
        );
        return;
      }
      final service = ref.read(quickTtsServiceProvider);
      final playback = ref.read(playbackNotifierProvider.notifier);
      if (stream) {
        await playback.playSynthesis(
          cancellation: cancellation,
          title: text,
          subtitle: asset.name,
          sourceTag: voiceBankQuickTestPlaybackSource,
          generate: (sink) => service.generate(
            entryId: entryId,
            asset: asset,
            provider: provider,
            text: text,
            cancellation: cancellation,
            sink: sink,
          ),
        );
      } else {
        final result = await service.generate(
          entryId: entryId,
          asset: asset,
          provider: provider,
          text: text,
          cancellation: cancellation,
        );
        cancellation.throwIfCancelled();
        if (!mounted) return;
        await playback.load(
          result.audioPath,
          text,
          subtitle: asset.name,
          sourceTag: voiceBankQuickTestPlaybackSource,
        );
      }
    } on TtsCancelledException {
      // Stopping and switching characters are normal, not failed history rows.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb &&
                      (error is BrowserSpeechConnectionException ||
                          (error is DioException && error.response == null))
                  ? l10n.webProviderNetworkError
                  : l10n.uiError2(error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}
