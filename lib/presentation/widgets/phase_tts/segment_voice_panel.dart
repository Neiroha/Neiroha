import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Right-side sentence list for Phase TTS.
///
/// Header with progress stats, a wrapping action toolbar, status filters and
/// one card per sentence: text first, then a voice pill and the play /
/// generate actions. Less frequent actions (style, edit, delete) live in the
/// card's overflow menu so they can't be hit by accident.
class SegmentVoicePanel extends ConsumerStatefulWidget {
  final db.PhaseTtsProject project;
  final List<db.PhaseTtsSegment> segments;
  final List<db.VoiceAsset> bankAssets;
  final Set<String> generatingSegmentIds;
  final Future<void> Function(String? voiceAssetId) onApplyVoiceToAll;
  final void Function(db.PhaseTtsSegment segment, String? voiceAssetId)
  onVoiceChanged;
  final void Function(db.PhaseTtsSegment segment, int index) onPlay;
  final Future<void> Function(db.PhaseTtsSegment segment)? onGenerate;
  final ValueChanged<String> onDelete;
  final Future<void> Function(db.PhaseTtsSegment segment, String text)
  onEditText;
  final VoidCallback onChanged;
  final VoidCallback onPlayAll;
  final VoidCallback onGenerateAll;
  final VoidCallback? onNormalize;
  final bool generatingAll;

  const SegmentVoicePanel({
    super.key,
    required this.project,
    required this.segments,
    required this.bankAssets,
    required this.generatingSegmentIds,
    required this.onApplyVoiceToAll,
    required this.onVoiceChanged,
    required this.onPlay,
    required this.onGenerate,
    required this.onDelete,
    required this.onEditText,
    required this.onChanged,
    required this.onPlayAll,
    required this.onGenerateAll,
    required this.onNormalize,
    required this.generatingAll,
  });

  @override
  ConsumerState<SegmentVoicePanel> createState() => _SegmentVoicePanelState();
}

class _SegmentVoicePanelState extends ConsumerState<SegmentVoicePanel> {
  String? _bulkVoiceId;
  _SegmentFilter _filter = _SegmentFilter.all;
  PhaseSegmentSettings _settings = const PhaseSegmentSettings();
  String? _projectSlug;
  Timer? _saveTimer;
  Future<dynamic> _pendingSave = Future<dynamic>.value();

  // Cached during initState — `ref.read` is unsafe in dispose() because
  // ConsumerStatefulElement is already torn down by then. The service object
  // itself lives in the enclosing ProviderScope, so calling it post-dispose
  // is fine.
  late final PhaseSegmentSettingsFileService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = ref.read(phaseSegmentSettingsFileServiceProvider);
    unawaited(_loadSettings());
  }

  @override
  void didUpdateWidget(covariant SegmentVoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _settings = const PhaseSegmentSettings();
      _bulkVoiceId = null;
      _projectSlug = null;
      unawaited(_loadSettings());
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final slug = _projectSlug;
    if (slug != null) {
      final service = _settingsService;
      final settings = _settings;
      unawaited(
        _pendingSave
            .catchError((_) {})
            .then((_) => service.save(slug, settings)),
      );
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final slug = await _ensureProjectSlug();
    final settings = await _settingsService.load(slug);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<String> _ensureProjectSlug() async {
    final existing = _projectSlug;
    if (existing != null) return existing;
    final slug = await ref
        .read(storageServiceProvider)
        .ensurePhaseProjectSlug(widget.project.id);
    if (mounted) setState(() => _projectSlug = slug);
    return slug;
  }

  void _setSegmentSettings(
    String segmentId,
    SegmentVoiceSettings settings, {
    bool saveNow = false,
  }) {
    final next = Map<String, SegmentVoiceSettings>.from(_settings.bySegmentId);
    if (settings.isEmpty) {
      next.remove(segmentId);
    } else {
      next[segmentId] = settings;
    }
    widget.onChanged();
    setState(() => _settings = _settings.copyWith(bySegmentId: next));
    if (saveNow) {
      _saveTimer?.cancel();
      unawaited(_saveSettings());
    } else {
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveSettings());
    });
  }

  Future<void> _saveSettings() {
    final service = _settingsService;
    final settings = _settings;
    _pendingSave = _pendingSave.catchError((_) {}).then((_) async {
      final slug = await _ensureProjectSlug();
      await service.save(slug, settings);
    });
    return _pendingSave.then((_) {});
  }

  Future<void> _generateSegment(db.PhaseTtsSegment segment) async {
    _saveTimer?.cancel();
    await _saveSettings();
    await widget.onGenerate?.call(segment);
  }

  Future<void> _applyBulkVoice(List<db.PhaseTtsSegment> segments) async {
    await widget.onApplyVoiceToAll(_bulkVoiceId);
    if (_settings.bySegmentId.isEmpty) return;

    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final providerById = {
      for (final provider in providers) provider.id: provider,
    };
    final selectedAsset = widget.bankAssets
        .where((asset) => asset.id == _bulkVoiceId)
        .firstOrNull;
    final provider = selectedAsset == null
        ? null
        : providerById[selectedAsset.providerId];
    final keepInstruction =
        selectedAsset != null &&
        provider != null &&
        _supportsVoiceInstruction(selectedAsset, provider);
    final keepAudioTag =
        selectedAsset != null &&
        provider != null &&
        _supportsAudioTags(selectedAsset, provider);

    final next = Map<String, SegmentVoiceSettings>.from(_settings.bySegmentId);
    for (final segment in segments) {
      final current = next[segment.id];
      if (current == null || current.isEmpty) continue;
      final pruned = SegmentVoiceSettings(
        voiceInstruction: keepInstruction ? current.voiceInstruction : null,
        audioTagPrefix: keepAudioTag ? current.audioTagPrefix : null,
      );
      if (pruned.isEmpty) {
        next.remove(segment.id);
      } else {
        next[segment.id] = pruned;
      }
    }
    setState(() => _settings = _settings.copyWith(bySegmentId: next));
    await _saveSettings();
  }

  void _changeSegmentVoice(db.PhaseTtsSegment segment, String? voiceAssetId) {
    widget.onVoiceChanged(segment, voiceAssetId);
    final current = _settings.bySegmentId[segment.id];
    if (current == null || current.isEmpty) return;

    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final providerById = {
      for (final provider in providers) provider.id: provider,
    };
    final selectedAsset = widget.bankAssets
        .where((asset) => asset.id == voiceAssetId)
        .firstOrNull;
    final provider = selectedAsset == null
        ? null
        : providerById[selectedAsset.providerId];
    final keepInstruction =
        selectedAsset != null &&
        provider != null &&
        _supportsVoiceInstruction(selectedAsset, provider);
    final keepAudioTag =
        selectedAsset != null &&
        provider != null &&
        _supportsAudioTags(selectedAsset, provider);

    _setSegmentSettings(
      segment.id,
      SegmentVoiceSettings(
        voiceInstruction: keepInstruction ? current.voiceInstruction : null,
        audioTagPrefix: keepAudioTag ? current.audioTagPrefix : null,
      ),
      saveNow: true,
    );
  }

  void _deleteSegment(db.PhaseTtsSegment segment) {
    _setSegmentSettings(
      segment.id,
      const SegmentVoiceSettings(),
      saveNow: true,
    );
    widget.onDelete(segment.id);
  }

  Future<void> _openSettingsDialog(db.PhaseTtsSegment segment) async {
    final providers = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final providerById = {
      for (final provider in providers) provider.id: provider,
    };
    final current =
        _settings.bySegmentId[segment.id] ?? const SegmentVoiceSettings();
    var selectedVoiceId = segment.voiceAssetId;
    final instructionCtrl = TextEditingController(
      text: current.voiceInstruction ?? '',
    );
    final audioTagCtrl = TextEditingController(
      text: current.audioTagPrefix ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedAsset = widget.bankAssets
                .where((asset) => asset.id == selectedVoiceId)
                .firstOrNull;
            final provider = selectedAsset == null
                ? null
                : providerById[selectedAsset.providerId];
            final supportsInstruction =
                selectedAsset != null &&
                provider != null &&
                _supportsVoiceInstruction(selectedAsset, provider);
            final supportsAudioTag =
                selectedAsset != null &&
                provider != null &&
                _supportsAudioTags(selectedAsset, provider);

            return AlertDialog(
              title: Text(AppLocalizations.of(context).uiSentenceVoice),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      segment.segmentText,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    _VoiceDropdown(
                      value: selectedVoiceId,
                      assets: widget.bankAssets,
                      hintText: AppLocalizations.of(context).uiVoice,
                      onChanged: (id) =>
                          setDialogState(() => selectedVoiceId = id),
                    ),
                    SizedBox(height: 10),
                    if (supportsInstruction)
                      TextField(
                        controller: instructionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiStyleDirection,
                          hintText: '焦虑地说，压低声音，语速稍快',
                        ),
                      ),
                    if (supportsAudioTag) ...[
                      SizedBox(height: 10),
                      TextField(
                        controller: audioTagCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiAudioTagPrefix,
                          hintText: '(紧张|深呼吸)',
                        ),
                      ),
                    ],
                    if (!supportsInstruction && !supportsAudioTag) ...[
                      SizedBox(height: 10),
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiNoPerSentenceStyleControls,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    instructionCtrl.clear();
                    audioTagCtrl.clear();
                    setDialogState(() => selectedVoiceId = null);
                  },
                  child: Text(AppLocalizations.of(context).uiClear),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context).uiCancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedVoiceId != segment.voiceAssetId) {
                      _changeSegmentVoice(segment, selectedVoiceId);
                    }
                    _setSegmentSettings(
                      segment.id,
                      SegmentVoiceSettings(
                        voiceInstruction: supportsInstruction
                            ? _normalizeText(instructionCtrl.text)
                            : null,
                        audioTagPrefix: supportsAudioTag
                            ? _normalizeText(audioTagCtrl.text)
                            : null,
                      ),
                      saveNow: true,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context).uiSave),
                ),
              ],
            );
          },
        );
      },
    );

    instructionCtrl.dispose();
    audioTagCtrl.dispose();
  }

  String? _normalizeText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _supportsVoiceInstruction(db.VoiceAsset asset, db.TtsProvider provider) {
    return switch (provider.adapterType) {
      'chatCompletionsTts' => _isMimoTtsModel(asset, provider),
      'cosyvoice' => true,
      'voxcpm2Native' => true,
      'geminiTts' => true,
      'elevenLabs' => true,
      'minimaxTts' => true,
      'indexTts' => true,
      _ => false,
    };
  }

  bool _supportsAudioTags(db.VoiceAsset asset, db.TtsProvider provider) {
    return _isMimoTtsModel(asset, provider);
  }

  bool _isMimoTtsModel(db.VoiceAsset asset, db.TtsProvider provider) {
    final model = (asset.modelName ?? provider.defaultModelName).toLowerCase();
    return provider.adapterType == 'chatCompletionsTts' &&
        model.contains('mimo') &&
        (model.contains('tts') ||
            model.contains('voiceclone') ||
            model.contains('voicedesign'));
  }

  Future<void> _openEditTextDialog(db.PhaseTtsSegment segment) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: segment.segmentText);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.phaseEditText),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
              ),
              if (segment.audioPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.phaseEditTextHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.uiSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next.isEmpty || next == segment.segmentText) return;
    await widget.onEditText(segment, next);
  }

  Future<void> _togglePlay(db.PhaseTtsSegment segment, int index) async {
    final playback = ref.read(playbackNotifierProvider);
    if (playback.isPlaying && playback.audioPath == segment.audioPath) {
      await ref.read(playbackNotifierProvider.notifier).stop();
      return;
    }
    widget.onPlay(segment, index);
  }

  bool _matchesFilter(db.PhaseTtsSegment segment) => switch (_filter) {
    _SegmentFilter.all => true,
    _SegmentFilter.pending => !_hasAudio(segment),
    _SegmentFilter.done => _hasAudio(segment),
    _SegmentFilter.failed => segment.error != null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordered = [...widget.segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final assetIds = widget.bankAssets.map((asset) => asset.id).toSet();
    final bulkValue = _bulkVoiceId != null && assetIds.contains(_bulkVoiceId)
        ? _bulkVoiceId
        : null;
    final doneCount = ordered.where(_hasAudio).length;
    final failedCount = ordered.where((s) => s.error != null).length;
    final pendingCount = ordered.length - doneCount;
    final unassignedCount = ordered.where((s) => s.voiceAssetId == null).length;
    final queuedCount = ordered
        .where((s) => !_hasAudio(s) && s.voiceAssetId != null)
        .length;
    final totalSeconds = ordered
        .where(_hasAudio)
        .fold<double>(0, (sum, s) => sum + (s.audioDuration ?? 0));
    final canGenerateAll =
        queuedCount > 0 &&
        widget.bankAssets.isNotEmpty &&
        !widget.generatingAll;
    // Only rebuild on play/stop transitions, not on every position tick.
    final playingPath = ref.watch(
      playbackNotifierProvider.select((s) => s.isPlaying ? s.audioPath : null),
    );
    final visible = [
      for (var i = 0; i < ordered.length; i++)
        if (_matchesFilter(ordered[i])) i,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          total: ordered.length,
          done: doneCount,
          failed: failedCount,
          unassigned: unassignedCount,
          totalSeconds: totalSeconds,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: canGenerateAll ? widget.onGenerateAll : null,
                icon: widget.generatingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(
                  queuedCount > 0 && !widget.generatingAll
                      ? l10n.uiGenerateAll2(queuedCount)
                      : l10n.uiGenerateAll,
                ),
              ),
              OutlinedButton.icon(
                onPressed: doneCount > 0 ? widget.onPlayAll : null,
                icon: const Icon(Icons.playlist_play_rounded, size: 18),
                label: Text(l10n.phasePlayAll),
              ),
              Tooltip(
                message: l10n.loudnessActionTooltip,
                child: OutlinedButton.icon(
                  onPressed: doneCount > 0 ? widget.onNormalize : null,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 16),
                  label: Text(l10n.loudnessAction),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: _VoiceDropdown(
                    value: bulkValue,
                    assets: widget.bankAssets,
                    hintText: l10n.uiVoiceForAll,
                    onChanged: (id) => setState(() => _bulkVoiceId = id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: ordered.isEmpty
                    ? null
                    : () => unawaited(_applyBulkVoice(ordered)),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: Text(l10n.phaseApplyVoiceToAll),
              ),
            ],
          ),
        ),
        if (ordered.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                for (final filter in _SegmentFilter.values) ...[
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(switch (filter) {
                      _SegmentFilter.all =>
                        '${l10n.phaseFilterAll} ${ordered.length}',
                      _SegmentFilter.pending =>
                        '${l10n.phaseFilterPending} $pendingCount',
                      _SegmentFilter.done =>
                        '${l10n.phaseFilterDone} $doneCount',
                      _SegmentFilter.failed =>
                        '${l10n.phaseFilterFailed} $failedCount',
                    }),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ordered.isEmpty
              ? _EmptyState(text: l10n.uiRunAutoSplitToCreateSegments)
              : visible.isEmpty
              ? _EmptyState(text: l10n.phaseNoFilterMatches)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final index = visible[i];
                    final segment = ordered[index];
                    final generating = widget.generatingSegmentIds.contains(
                      segment.id,
                    );
                    return _SegmentCard(
                      key: ValueKey(segment.id),
                      segment: segment,
                      index: index,
                      assets: widget.bankAssets,
                      settings: _settings.bySegmentId[segment.id],
                      isGenerating: generating,
                      isPlaying:
                          playingPath != null &&
                          playingPath == segment.audioPath,
                      onVoiceChanged: (id) => _changeSegmentVoice(segment, id),
                      onSettings: () => _openSettingsDialog(segment),
                      onEditText: () => _openEditTextDialog(segment),
                      onTogglePlay: () => _togglePlay(segment, index),
                      onDelete: () => _deleteSegment(segment),
                      onGenerate:
                          segment.voiceAssetId == null ||
                              generating ||
                              widget.onGenerate == null
                          ? null
                          : () => unawaited(_generateSegment(segment)),
                    );
                  },
                ),
        ),
        const PersistentAudioBar(onlyForSourceTag: phaseTtsPlaybackSource),
      ],
    );
  }
}

bool _hasAudio(db.PhaseTtsSegment segment) =>
    segment.audioPath != null && !segment.missing;

enum _SegmentFilter { all, pending, done, failed }

enum _SegmentStatus { pending, generating, done, failed }

const _doneColor = Color(0xFF4ADE80);
const _failedColor = Color(0xFFF87171);

class _PanelHeader extends StatelessWidget {
  final int total;
  final int done;
  final int failed;
  final int unassigned;
  final double totalSeconds;

  const _PanelHeader({
    required this.total,
    required this.done,
    required this.failed,
    required this.unassigned,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Colors.white.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.uiSEGMENTS,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              Text(
                l10n.phaseStatsGenerated(done, total),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              if (totalSeconds > 0)
                Text(
                  _formatClock(totalSeconds),
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (failed > 0)
                Text(
                  l10n.phaseStatsFailed(failed),
                  style: const TextStyle(fontSize: 12, color: _failedColor),
                ),
              if (unassigned > 0)
                Text(
                  l10n.phaseStatsUnassigned(unassigned),
                  style: const TextStyle(fontSize: 12, color: Colors.amber),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                color: done == total ? _doneColor : AppTheme.accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentCard extends StatefulWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> assets;
  final SegmentVoiceSettings? settings;
  final bool isGenerating;
  final bool isPlaying;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onSettings;
  final VoidCallback onEditText;
  final VoidCallback onTogglePlay;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const _SegmentCard({
    super.key,
    required this.segment,
    required this.index,
    required this.assets,
    required this.settings,
    required this.isGenerating,
    required this.isPlaying,
    required this.onVoiceChanged,
    required this.onSettings,
    required this.onEditText,
    required this.onTogglePlay,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  bool _expanded = false;

  _SegmentStatus get _status {
    if (widget.isGenerating) return _SegmentStatus.generating;
    if (widget.segment.error != null) return _SegmentStatus.failed;
    if (_hasAudio(widget.segment)) return _SegmentStatus.done;
    return _SegmentStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segment = widget.segment;
    final status = _status;
    final hasAudio = _hasAudio(segment);
    final settings = widget.settings;
    final hasSettings = settings != null && !settings.isEmpty;
    final statusColor = switch (status) {
      _SegmentStatus.pending => Colors.white.withValues(alpha: 0.12),
      _SegmentStatus.generating => AppTheme.accentColor,
      _SegmentStatus.done => _doneColor,
      _SegmentStatus.failed => _failedColor,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: widget.isPlaying
            ? AppTheme.accentColor.withValues(alpha: 0.10)
            : AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isPlaying
              ? AppTheme.accentColor.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _expanded = !_expanded),
                      onDoubleTap: widget.onEditText,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IndexBadge(index: widget.index, status: status),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3, right: 6),
                              child: Text(
                                segment.segmentText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                                maxLines: _expanded ? null : 3,
                                overflow: _expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasSettings) ...[
                      const SizedBox(height: 6),
                      _SettingsSummary(settings: settings),
                    ],
                    if (segment.error != null && !widget.isGenerating) ...[
                      const SizedBox(height: 6),
                      Tooltip(
                        message: segment.error!,
                        child: Text(
                          segment.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _failedColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: _VoiceChip(
                            value: segment.voiceAssetId,
                            assets: widget.assets,
                            onChanged: widget.onVoiceChanged,
                          ),
                        ),
                        const Spacer(),
                        if (hasAudio && segment.audioDuration != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              _formatShort(segment.audioDuration!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.45),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        if (hasAudio)
                          _CardAction(
                            tooltip: widget.isPlaying
                                ? l10n.phaseStopPlayback
                                : l10n.phasePlay,
                            icon: widget.isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: widget.isPlaying
                                ? AppTheme.accentColor
                                : null,
                            onPressed: widget.onTogglePlay,
                          ),
                        if (widget.isGenerating)
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          _CardAction(
                            tooltip: segment.audioPath != null
                                ? l10n.uiRegenerate
                                : l10n.uiGenerate,
                            icon: segment.audioPath != null
                                ? Icons.refresh_rounded
                                : Icons.auto_awesome_rounded,
                            color: widget.onGenerate == null
                                ? null
                                : AppTheme.accentColor,
                            onPressed: widget.onGenerate,
                          ),
                        PopupMenuButton<String>(
                          tooltip: l10n.phaseMoreActions,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 180),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                            fixedSize: const Size(34, 34),
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'style':
                                widget.onSettings();
                              case 'edit':
                                widget.onEditText();
                              case 'delete':
                                widget.onDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            _menuItem(
                              'style',
                              Icons.tune_rounded,
                              l10n.uiVoiceSettings,
                              highlight: hasSettings,
                            ),
                            _menuItem(
                              'edit',
                              Icons.edit_note_rounded,
                              l10n.phaseEditText,
                            ),
                            const PopupMenuDivider(),
                            _menuItem(
                              'delete',
                              Icons.delete_outline_rounded,
                              l10n.uiDeleteSegment,
                              destructive: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool highlight = false,
    bool destructive = false,
  }) {
    final color = destructive
        ? _failedColor
        : highlight
        ? AppTheme.accentColor
        : null;
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  final int index;
  final _SegmentStatus status;

  const _IndexBadge({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      _SegmentStatus.done => (_doneColor.withValues(alpha: 0.14), _doneColor),
      _SegmentStatus.failed => (
        _failedColor.withValues(alpha: 0.14),
        _failedColor,
      ),
      _SegmentStatus.generating => (
        AppTheme.accentColor.withValues(alpha: 0.2),
        Colors.white,
      ),
      _SegmentStatus.pending => (
        Colors.white.withValues(alpha: 0.05),
        Colors.white.withValues(alpha: 0.5),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Lightweight voice selector: a pill showing the current voice that opens a
/// menu, instead of a full form dropdown per row.
class _VoiceChip extends StatelessWidget {
  static const _unassigned = '';

  final String? value;
  final List<db.VoiceAsset> assets;
  final ValueChanged<String?> onChanged;

  const _VoiceChip({
    required this.value,
    required this.assets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = assets.where((a) => a.id == value).firstOrNull;
    final assigned = current != null;
    return PopupMenuButton<String>(
      tooltip: l10n.uiVoice,
      initialValue: current?.id ?? _unassigned,
      onSelected: (id) => onChanged(id == _unassigned ? null : id),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: _unassigned,
          height: 36,
          child: Text(
            l10n.uiUnassigned,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        for (final asset in assets)
          PopupMenuItem<String>(
            value: asset.id,
            height: 36,
            child: Row(
              children: [
                Icon(
                  asset.id == value
                      ? Icons.check_rounded
                      : Icons.record_voice_over_rounded,
                  size: 16,
                  color: asset.id == value
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    asset.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(left: 8, right: 4),
        decoration: BoxDecoration(
          color: assigned
              ? AppTheme.accentColor.withValues(alpha: 0.14)
              : Colors.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 14,
              color: assigned ? AppTheme.accentColor : Colors.amber,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                current?.name ?? l10n.uiVoice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: assigned
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.amber,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  const _CardAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      color: color ?? Colors.white.withValues(alpha: 0.75),
      disabledColor: Colors.white.withValues(alpha: 0.18),
      icon: Icon(icon),
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  final SegmentVoiceSettings settings;

  const _SettingsSummary({required this.settings});

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (settings.voiceInstruction != null &&
          settings.voiceInstruction!.isNotEmpty)
        settings.voiceInstruction!,
      if (settings.audioTagPrefix != null &&
          settings.audioTagPrefix!.isNotEmpty)
        settings.audioTagPrefix!,
    ];
    return Row(
      children: [
        Icon(
          Icons.tune_rounded,
          size: 12,
          color: AppTheme.accentColor.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            parts.join('  |  '),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.accentColor.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VoiceDropdown extends StatelessWidget {
  final String? value;
  final List<db.VoiceAsset> assets;
  final String hintText;
  final ValueChanged<String?> onChanged;

  const _VoiceDropdown({
    required this.value,
    required this.assets,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      isExpanded: true,
      initialValue: value,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            AppLocalizations.of(context).uiUnassigned,
            style: TextStyle(fontSize: 12),
          ),
        ),
        for (final asset in assets)
          DropdownMenuItem<String>(
            value: asset.id,
            child: Text(
              asset.name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.segment_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatClock(double seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  final clock = '$mm:${s.toString().padLeft(2, '0')}';
  return h > 0 ? '$h:$clock' : clock;
}

String _formatShort(double seconds) {
  if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
  return _formatClock(seconds);
}
