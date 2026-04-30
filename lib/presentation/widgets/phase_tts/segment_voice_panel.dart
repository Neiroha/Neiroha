import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/phase_segment_settings_file.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/persistent_audio_bar.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Right-side sentence list for Phase TTS.
///
/// The list stays compact: voice selection, playback, regeneration, and a
/// settings dialog for per-sentence style controls.
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
  final VoidCallback onChanged;
  final VoidCallback onPlayAll;
  final VoidCallback onGenerateAll;
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
    required this.onChanged,
    required this.onPlayAll,
    required this.onGenerateAll,
    required this.generatingAll,
  });

  @override
  ConsumerState<SegmentVoicePanel> createState() => _SegmentVoicePanelState();
}

class _SegmentVoicePanelState extends ConsumerState<SegmentVoicePanel> {
  String? _bulkVoiceId;
  PhaseSegmentSettings _settings = const PhaseSegmentSettings();
  String? _projectSlug;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
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
      final service = ref.read(phaseSegmentSettingsFileServiceProvider);
      unawaited(service.save(slug, _settings));
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final slug = await _ensureProjectSlug();
    final settings = await ref
        .read(phaseSegmentSettingsFileServiceProvider)
        .load(slug);
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
    final next = Map<String, SegmentVoiceSettings>.from(
      _settings.bySegmentId,
    );
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

  Future<void> _saveSettings() async {
    final slug = await _ensureProjectSlug();
    await ref
        .read(phaseSegmentSettingsFileServiceProvider)
        .save(slug, _settings);
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
    final keepInstruction = selectedAsset != null &&
        provider != null &&
        _supportsVoiceInstruction(selectedAsset, provider);
    final keepAudioTag = selectedAsset != null &&
        provider != null &&
        _supportsAudioTags(selectedAsset, provider);

    final next = Map<String, SegmentVoiceSettings>.from(
      _settings.bySegmentId,
    );
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
    final keepInstruction = selectedAsset != null &&
        provider != null &&
        _supportsVoiceInstruction(selectedAsset, provider);
    final keepAudioTag = selectedAsset != null &&
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
    final current = _settings.bySegmentId[segment.id] ??
        const SegmentVoiceSettings();
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
            final supportsInstruction = selectedAsset != null &&
                provider != null &&
                _supportsVoiceInstruction(selectedAsset, provider);
            final supportsAudioTag = selectedAsset != null &&
                provider != null &&
                _supportsAudioTags(selectedAsset, provider);

            return AlertDialog(
              title: const Text('Sentence Voice'),
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
                    const SizedBox(height: 12),
                    _VoiceDropdown(
                      value: selectedVoiceId,
                      assets: widget.bankAssets,
                      hintText: 'Voice',
                      onChanged: (id) =>
                          setDialogState(() => selectedVoiceId = id),
                    ),
                    const SizedBox(height: 10),
                    if (supportsInstruction)
                      TextField(
                        controller: instructionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Style / direction',
                          hintText: '焦虑地说，压低声音，语速稍快',
                        ),
                      ),
                    if (supportsAudioTag) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: audioTagCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Audio tag prefix',
                          hintText: '(紧张|深呼吸)',
                        ),
                      ),
                    ],
                    if (!supportsInstruction && !supportsAudioTag) ...[
                      const SizedBox(height: 10),
                      TextField(
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'No per-sentence style controls',
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
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
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
                  child: const Text('Save'),
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

  bool _supportsVoiceInstruction(
    db.VoiceAsset asset,
    db.TtsProvider provider,
  ) {
    return switch (provider.adapterType) {
      'chatCompletionsTts' => _isMimoTtsModel(asset, provider),
      'cosyvoice' => true,
      'voxcpm2Native' => true,
      'geminiTts' => true,
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

  @override
  Widget build(BuildContext context) {
    final ordered = [...widget.segments]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final assetIds = widget.bankAssets.map((asset) => asset.id).toSet();
    final bulkValue = _bulkVoiceId != null && assetIds.contains(_bulkVoiceId)
        ? _bulkVoiceId
        : null;
    final hasGeneratedAudio = ordered.any(
      (segment) => segment.audioPath != null && !segment.missing,
    );
    final canGenerateAll = ordered.isNotEmpty &&
        widget.bankAssets.isNotEmpty &&
        !widget.generatingAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'SEGMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDim,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${ordered.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
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
                  height: 36,
                  child: _VoiceDropdown(
                    value: bulkValue,
                    assets: widget.bankAssets,
                    hintText: 'Voice for all',
                    onChanged: (id) => setState(() => _bulkVoiceId = id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: ordered.isEmpty
                    ? null
                    : () => unawaited(_applyBulkVoice(ordered)),
                icon: const Icon(Icons.done_all_rounded, size: 14),
                label: const Text('Apply All'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: canGenerateAll ? widget.onGenerateAll : null,
                icon: widget.generatingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Generate All'),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Play all generated audio',
                onPressed: hasGeneratedAudio ? widget.onPlayAll : null,
                icon: const Icon(Icons.playlist_play_rounded, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: ordered.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: ordered.length,
                  itemBuilder: (context, index) {
                    final segment = ordered[index];
                    final rowSettings = _settings.bySegmentId[segment.id];
                    return _SegmentVoiceRow(
                      segment: segment,
                      index: index,
                      assets: widget.bankAssets,
                      settings: rowSettings,
                      isGenerating: widget.generatingSegmentIds.contains(
                        segment.id,
                      ),
                      onVoiceChanged: (id) => _changeSegmentVoice(segment, id),
                      onSettings: () => _openSettingsDialog(segment),
                      onPlay: () => widget.onPlay(segment, index),
                      onDelete: () => _deleteSegment(segment),
                      onGenerate:
                          segment.voiceAssetId == null ||
                              widget.generatingSegmentIds.contains(
                                segment.id,
                              ) ||
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

class _SegmentVoiceRow extends StatelessWidget {
  final db.PhaseTtsSegment segment;
  final int index;
  final List<db.VoiceAsset> assets;
  final SegmentVoiceSettings? settings;
  final bool isGenerating;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback onSettings;
  final VoidCallback onPlay;
  final VoidCallback? onGenerate;
  final VoidCallback onDelete;

  const _SegmentVoiceRow({
    required this.segment,
    required this.index,
    required this.assets,
    required this.settings,
    required this.isGenerating,
    required this.onVoiceChanged,
    required this.onSettings,
    required this.onPlay,
    required this.onGenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final assetIds = assets.map((asset) => asset.id).toSet();
    final value =
        segment.voiceAssetId != null && assetIds.contains(segment.voiceAssetId)
        ? segment.voiceAssetId
        : null;
    final hasSettings = settings != null && !settings!.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
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
                  color: Colors.white.withValues(alpha: 0.05),
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
                  height: 34,
                  child: _VoiceDropdown(
                    value: value,
                    assets: assets,
                    hintText: 'Voice',
                    onChanged: onVoiceChanged,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Voice settings',
                icon: Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: hasSettings
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.35),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onSettings,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete segment',
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
              const SizedBox(width: 4),
              _StatusButton(
                isGenerating: isGenerating,
                hasAudio: segment.audioPath != null,
                error: segment.error,
                onPlay: onPlay,
              ),
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
                tooltip: segment.audioPath != null ? 'Regenerate' : 'Generate',
                onPressed: onGenerate,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            segment.segmentText,
            style: const TextStyle(fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasSettings) ...[
            const SizedBox(height: 6),
            _SettingsSummary(settings: settings!),
          ],
        ],
      ),
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
      if (settings.audioTagPrefix != null && settings.audioTagPrefix!.isNotEmpty)
        settings.audioTagPrefix!,
    ];
    return Text(
      parts.join('  |  '),
      style: TextStyle(
        fontSize: 11,
        color: AppTheme.accentColor.withValues(alpha: 0.85),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      isExpanded: true,
      initialValue: value,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('-- Unassigned --', style: TextStyle(fontSize: 12)),
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

class _StatusButton extends StatelessWidget {
  final bool isGenerating;
  final bool hasAudio;
  final String? error;
  final VoidCallback onPlay;

  const _StatusButton({
    required this.isGenerating,
    required this.hasAudio,
    required this.error,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (hasAudio) {
      return IconButton(
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPlay,
      );
    }
    if (error != null) {
      return Tooltip(
        message: error!,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Run Auto Split to create segments',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
