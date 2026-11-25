part of 'loudness_normalize_dialog.dart';

/// Preset picker, status, analysis and action sections of the dialog.
extension _LoudnessSections on _LoudnessDialogState {
  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: context.fg.withValues(alpha: 0.45),
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
                    : (_) => _update(() => _preset = preset),
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
                      : (v) => _update(() => _customLufs = v),
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
                        ? context.colors.success
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
                fg: context.fg,
                success: context.colors.success,
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
                : () => _update(() => _cancelRequested = true),
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
        color: context.colors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fg.withValues(alpha: 0.06)),
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
            color: context.fg.withValues(alpha: 0.45),
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
  final Color fg;
  final Color success;

  _DistributionPainter({
    required this.values,
    required this.target,
    required this.tolerance,
    required this.fg,
    required this.success,
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
        ..color = fg.withValues(alpha: 0.12)
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
          ? success.withValues(alpha: 0.85)
          : Colors.amberAccent.withValues(alpha: 0.7);
      canvas.drawLine(Offset(x(v), 12), Offset(x(v), axisY), tick);
    }

    void label(String text, double atX, TextAlign align) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.45)),
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
      old.tolerance != tolerance ||
      old.fg != fg ||
      old.success != success;
}
