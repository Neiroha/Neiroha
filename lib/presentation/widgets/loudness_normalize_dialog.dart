import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/loudness_normalizer.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

part 'loudness_dialog_sections.dart';

/// One generated clip offered to the loudness dialog.
class LoudnessItem {
  final String id;
  final String path;

  /// Speaker of the clip; its character loudness offset is applied.
  final String? voiceAssetId;

  const LoudnessItem({required this.id, required this.path, this.voiceAssetId});
}

/// Check FFmpeg, then open the batch loudness dialog for [items].
///
/// With [bankId] the dialog starts from that bank's loudness target and
/// offers the per-character offsets. [beforeApply] runs right before files
/// are rewritten — editors with their own players (Video Dub) use it to
/// release file handles. Global playback is always stopped. Returns true
/// when at least one file changed.
Future<bool> runLoudnessNormalization({
  required BuildContext context,
  required WidgetRef ref,
  required List<LoudnessItem> items,
  String? bankId,
  Future<void> Function()? beforeApply,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final present = [
    for (final item in items)
      if (File(item.path).existsSync()) item,
  ];
  if (present.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.loudnessNoAudio)));
    return false;
  }
  final capabilities = ref.read(platformCapabilitiesProvider);
  if (!capabilities.supportsLocalAudioMuxing) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.uiFFmpegUnavailableOnPlatform(capabilities.platformLabel),
        ),
      ),
    );
    return false;
  }
  if (!await ref.read(ffmpegServiceProvider).isAvailable()) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.loudnessFfmpegRequired)),
    );
    return false;
  }
  final database = ref.read(databaseProvider);
  final bank = bankId == null ? null : await database.getBankById(bankId);
  final offsets = {
    for (final a in await database.getAllVoiceAssets())
      if (a.loudnessOffsetDb != 0) a.id: a.loudnessOffsetDb,
  };
  if (!context.mounted) return false;
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LoudnessDialog(
      items: present,
      bankTargetLufs: bank?.loudnessTargetLufs,
      offsets: offsets,
      beforeApply: beforeApply,
    ),
  );
  return changed ?? false;
}

const _kTargetKey = 'loudness.targetLufs';
const _kBackupKey = 'loudness.keepBackup';
const _minLufs = -30.0;
const _maxLufs = -10.0;

enum _Preset { loud, standard, soft, broadcast, custom }

extension on _Preset {
  double? get lufs => switch (this) {
    _Preset.loud => -14,
    _Preset.standard => -16,
    _Preset.soft => -20,
    _Preset.broadcast => -23,
    _Preset.custom => null,
  };
}

enum _Phase { idle, analyzing, analyzed, applying, done }

class _LoudnessDialog extends ConsumerStatefulWidget {
  final List<LoudnessItem> items;
  final double? bankTargetLufs;
  final Map<String, double> offsets;
  final Future<void> Function()? beforeApply;

  const _LoudnessDialog({
    required this.items,
    required this.bankTargetLufs,
    required this.offsets,
    required this.beforeApply,
  });

  @override
  ConsumerState<_LoudnessDialog> createState() => _LoudnessDialogState();
}

class _LoudnessDialogState extends ConsumerState<_LoudnessDialog> {
  _Preset _preset = _Preset.standard;
  double _customLufs = -18;
  bool _keepBackup = true;
  _Phase _phase = _Phase.idle;
  int _progress = 0;
  bool _cancelRequested = false;

  final Map<String, LoudnessMeasurement> _measured = {};
  final Map<String, String> _errors = {};
  int _adjusted = 0;
  int _onTarget = 0;
  int _silent = 0;
  int _failed = 0;
  int _restored = 0;
  String? _lastError;
  late bool _useOffsets = _hasOffsets;
  late final int _restorable = widget.items
      .where((i) => LoudnessNormalizer.hasRestorableBackup(i.path))
      .length;

  int get _concurrency =>
      (Platform.numberOfProcessors ~/ 2).clamp(1, 4).toInt();

  double get _targetLufs => _preset.lufs ?? _customLufs;

  bool get _hasOffsets =>
      widget.items.any((i) => (widget.offsets[i.voiceAssetId] ?? 0) != 0);

  double _offsetFor(LoudnessItem item) =>
      _useOffsets ? widget.offsets[item.voiceAssetId] ?? 0 : 0;

  LoudnessTarget _targetFor(LoudnessItem item) => LoudnessTarget(
    lufs: LoudnessNormalizer.targetFor(
      bankLufs: _targetLufs,
      offsetDb: _offsetFor(item),
    ),
  );

  bool get _busy => _phase == _Phase.analyzing || _phase == _Phase.applying;

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    final bankTarget = widget.bankTargetLufs;
    if (bankTarget != null) {
      _selectTarget(bankTarget);
    }
    unawaited(_loadPrefs());
  }

  void _selectTarget(double lufs) {
    final preset = _Preset.values.where((p) => p.lufs == lufs).firstOrNull;
    _preset = preset ?? _Preset.custom;
    _customLufs = lufs.clamp(_minLufs, _maxLufs).toDouble();
  }

  Future<void> _loadPrefs() async {
    final database = ref.read(databaseProvider);
    final rawTarget = double.tryParse(
      await database.getSetting(_kTargetKey) ?? '',
    );
    final rawBackup = await database.getSetting(_kBackupKey);
    if (!mounted) return;
    setState(() {
      // A project's bank target wins over the last free-standing choice.
      if (rawTarget != null && widget.bankTargetLufs == null) {
        _selectTarget(rawTarget);
      }
      if (rawBackup != null) _keepBackup = rawBackup != 'false';
    });
  }

  Future<void> _restore() async {
    await ref.read(playbackNotifierProvider.notifier).stop();
    await widget.beforeApply?.call();
    var restored = 0;
    for (final item in widget.items) {
      try {
        if (await LoudnessNormalizer.restoreFile(item.path)) restored++;
      } catch (e) {
        _lastError = '$e';
      }
    }
    if (!mounted) return;
    setState(() {
      _restored = restored;
      _phase = _Phase.done;
    });
  }

  Future<void> _savePrefs() async {
    final database = ref.read(databaseProvider);
    await database.setSetting(_kTargetKey, _targetLufs.toString());
    await database.setSetting(_kBackupKey, _keepBackup.toString());
  }

  Future<void> _runPool(
    List<LoudnessItem> items,
    Future<void> Function(LoudnessItem item) task,
  ) async {
    var next = 0;
    final workers = math.min(_concurrency, items.length);
    await Future.wait([
      for (var w = 0; w < workers; w++)
        () async {
          while (!_cancelRequested && next < items.length) {
            final item = items[next++];
            await task(item);
            if (mounted) setState(() => _progress++);
          }
        }(),
    ]);
  }

  Future<void> _analyze() async {
    final normalizer = ref.read(loudnessNormalizerProvider);
    setState(() {
      _phase = _Phase.analyzing;
      _progress = 0;
      _cancelRequested = false;
      _measured.clear();
      _errors.clear();
    });
    await _runPool(widget.items, (item) async {
      try {
        _measured[item.id] = await normalizer.measure(
          LoudnessNormalizer.sourcePathFor(item.path),
        );
      } catch (e) {
        _errors[item.id] = '$e';
      }
    });
    if (!mounted) return;
    setState(() => _phase = _cancelRequested ? _Phase.idle : _Phase.analyzed);
  }

  Future<void> _apply() async {
    unawaited(_savePrefs());
    await ref.read(playbackNotifierProvider.notifier).stop();
    await widget.beforeApply?.call();
    if (!mounted) return;
    final normalizer = ref.read(loudnessNormalizerProvider);
    final keepBackup = _keepBackup;
    setState(() {
      _phase = _Phase.applying;
      _progress = 0;
      _cancelRequested = false;
      _adjusted = 0;
      _onTarget = 0;
      _silent = 0;
      _failed = _errors.length;
      _lastError = _errors.values.lastOrNull;
    });
    final candidates = [
      for (final item in widget.items)
        if (_measured.containsKey(item.id)) item,
    ];
    await _runPool(candidates, (item) async {
      final outcome = await normalizer.normalizeFile(
        item.path,
        _targetFor(item),
        measured: _measured[item.id],
        keepBackup: keepBackup,
      );
      switch (outcome.kind) {
        case LoudnessOutcomeKind.adjusted:
          _adjusted++;
        case LoudnessOutcomeKind.onTarget:
          _onTarget++;
        case LoudnessOutcomeKind.silent:
          _silent++;
        case LoudnessOutcomeKind.failed:
          _failed++;
          _lastError = outcome.error;
      }
    });
    if (!mounted) return;
    setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: AppTheme.accentColor),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.loudnessTitle)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.loudnessIntro(widget.items.length),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              _sectionLabel(l10n.loudnessTarget),
              const SizedBox(height: 8),
              _buildPresetPicker(l10n),
              const SizedBox(height: 4),
              if (_hasOffsets)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _useOffsets,
                  onChanged: _busy || _phase == _Phase.done
                      ? null
                      : (v) => setState(() => _useOffsets = v),
                  title: Text(l10n.loudnessUseOffsets),
                  subtitle: Text(
                    l10n.loudnessUseOffsetsHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _keepBackup,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _keepBackup = v),
                title: Text(l10n.loudnessKeepBackup),
                subtitle: Text(
                  l10n.loudnessKeepBackupHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusArea(l10n),
            ],
          ),
        ),
      ),
      actions: _buildActions(l10n),
    );
  }
}
