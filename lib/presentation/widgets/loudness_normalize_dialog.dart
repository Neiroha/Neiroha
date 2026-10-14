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
  static const _kTargetKey = 'loudness.targetLufs';
  static const _kBackupKey = 'loudness.keepBackup';
  static const _minLufs = -30.0;
  static const _maxLufs = -10.0;

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

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );

  Widget _buildPresetPicker(AppLocalizations l10n) {
    String label(_Preset p) => switch (p) {
      _Preset.loud => l10n.loudnessPresetLoud,
      _Preset.standard => l10n.loudnessPresetStandard,
      _Preset.soft => l10n.loudnessPresetSoft,
      _Preset.broadcast => l10n.loudnessPresetBroadcast,
      _Preset.custom => l10n.loudnessPresetCustom,
    };
    final hint = switch (_preset) {
      _Preset.loud => l10n.loudnessPresetLoudHint,
      _Preset.standard => l10n.loudnessPresetStandardHint,
      _Preset.soft => l10n.loudnessPresetSoftHint,
      _Preset.broadcast => l10n.loudnessPresetBroadcastHint,
      _Preset.custom => l10n.loudnessPresetCustomHint,
    };
    final locked = _phase == _Phase.applying || _phase == _Phase.done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _Preset.values)
              ChoiceChip(
                label: Text(label(preset)),
                selected: _preset == preset,
                onSelected: locked
                    ? null
                    : (_) => setState(() => _preset = preset),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.accentColor.withValues(alpha: 0.95),
          ),
        ),
        if (_preset == _Preset.custom)
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _customLufs,
                  min: _minLufs,
                  max: _maxLufs,
                  divisions: ((_maxLufs - _minLufs) * 2).round(),
                  label: '${_customLufs.toStringAsFixed(1)} LUFS',
                  onChanged: locked
                      ? null
                      : (v) => setState(() => _customLufs = v),
                ),
              ),
              SizedBox(
                width: 82,
                child: Text(
                  '${_customLufs.toStringAsFixed(1)} LUFS',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusArea(AppLocalizations l10n) {
    final total = switch (_phase) {
      _Phase.applying => _measured.length,
      _ => widget.items.length,
    };
    switch (_phase) {
      case _Phase.idle:
        return const SizedBox.shrink();
      case _Phase.analyzing:
      case _Phase.applying:
        final text = _phase == _Phase.analyzing
            ? l10n.loudnessAnalyzing(_progress, total)
            : l10n.loudnessApplying(_progress, total);
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: total == 0 ? null : _progress / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text(text, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      case _Phase.analyzed:
        return _buildAnalysis(l10n);
      case _Phase.done:
        return _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _failed == 0
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: _failed == 0
                        ? const Color(0xFF4ADE80)
                        : Colors.amberAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _restored > 0
                          ? l10n.loudnessRestored(_restored)
                          : l10n.loudnessSummary(
                              _adjusted,
                              _onTarget,
                              _silent,
                              _failed,
                            ),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              if (_lastError != null) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.loudnessLastError(_lastError!),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _buildAnalysis(AppLocalizations l10n) {
    // Plot each clip relative to the base target: a narrator meant to sit
    // 3 dB under the cast counts as "on target" at base − 3.
    final values = <double>[];
    var toAdjust = 0;
    final tolerance = const LoudnessTarget(lufs: 0).toleranceLu;
    for (final item in widget.items) {
      final m = _measured[item.id];
      if (m == null || m.isSilent) continue;
      values.add(m.integratedLufs - _offsetFor(item));
      if ((_targetFor(item).lufs - m.integratedLufs).abs() > tolerance) {
        toAdjust++;
      }
    }
    if (values.isEmpty) {
      return _Panel(
        child: Text(l10n.loudnessNoAudio, style: const TextStyle(fontSize: 12)),
      );
    }
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final target = LoudnessTarget(lufs: _targetLufs);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Stat(
                label: l10n.loudnessRange,
                value:
                    '${lo.toStringAsFixed(1)} ~ ${hi.toStringAsFixed(1)} LUFS',
              ),
              _Stat(
                label: l10n.loudnessSpread,
                value: '${(hi - lo).toStringAsFixed(1)} LU',
              ),
              _Stat(
                label: l10n.loudnessNeedsChange,
                value: '$toAdjust / ${_measured.length}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: CustomPaint(
              painter: _DistributionPainter(
                values: values,
                target: target.lufs,
                tolerance: target.toleranceLu,
              ),
            ),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.loudnessLastError(_errors.values.last),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.redAccent.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.idle:
        return [
          if (_restorable > 0)
            TextButton.icon(
              onPressed: () => unawaited(_restore()),
              icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
              label: Text(l10n.loudnessRestore(_restorable)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.uiCancel),
          ),
          FilledButton.icon(
            onPressed: () => unawaited(_analyze()),
            icon: const Icon(Icons.query_stats_rounded, size: 16),
            label: Text(l10n.loudnessAnalyze),
          ),
        ];
      case _Phase.analyzing:
      case _Phase.applying:
        return [
          TextButton(
            onPressed: _cancelRequested
                ? null
                : () => setState(() => _cancelRequested = true),
            child: Text(l10n.loudnessStop),
          ),
        ];
      case _Phase.analyzed:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.uiCancel),
          ),
          FilledButton.icon(
            onPressed: _measured.isEmpty ? null : () => unawaited(_apply()),
            icon: const Icon(Icons.graphic_eq_rounded, size: 16),
            label: Text(l10n.loudnessApply(_measured.length)),
          ),
        ];
      case _Phase.done:
        return [
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _adjusted > 0 || _restored > 0),
            child: Text(l10n.uiDone),
          ),
        ];
    }
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// One tick per clip on a LUFS axis, with the target band highlighted —
/// shows at a glance how scattered the batch is before applying.
class _DistributionPainter extends CustomPainter {
  final List<double> values;
  final double target;
  final double tolerance;

  _DistributionPainter({
    required this.values,
    required this.target,
    required this.tolerance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lo = math.min(values.reduce(math.min), target) - 2;
    final hi = math.max(values.reduce(math.max), target) + 2;
    double x(double v) => (v - lo) / (hi - lo) * size.width;
    const axisY = 28.0;

    canvas.drawLine(
      Offset(0, axisY),
      Offset(size.width, axisY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    final band = Rect.fromLTRB(
      x(target - tolerance) - 1,
      6,
      x(target + tolerance) + 1,
      axisY + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(3)),
      Paint()..color = AppTheme.accentColor.withValues(alpha: 0.28),
    );
    canvas.drawLine(
      Offset(x(target), 2),
      Offset(x(target), axisY + 8),
      Paint()
        ..color = AppTheme.accentColor
        ..strokeWidth = 2,
    );

    final tick = Paint()..strokeWidth = 2;
    for (final v in values) {
      final off = (v - target).abs() <= tolerance;
      tick.color = off
          ? const Color(0xFF4ADE80).withValues(alpha: 0.85)
          : Colors.amberAccent.withValues(alpha: 0.7);
      canvas.drawLine(Offset(x(v), 12), Offset(x(v), axisY), tick);
    }

    void label(String text, double atX, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = switch (align) {
        TextAlign.left => atX,
        TextAlign.right => atX - tp.width,
        _ => atX - tp.width / 2,
      };
      tp.paint(
        canvas,
        Offset(dx.clamp(0, size.width - tp.width).toDouble(), axisY + 4),
      );
    }

    label(lo.toStringAsFixed(0), 0, TextAlign.left);
    label(hi.toStringAsFixed(0), size.width, TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter old) =>
      old.values != values ||
      old.target != target ||
      old.tolerance != tolerance;
}
