import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Pause / fade settings for Play All and Export Merged, plus the project's
/// "normalize after generation" switch. Returns the updated project, or
/// null when cancelled.
Future<db.PhaseTtsProject?> showPhaseMergeSettingsDialog({
  required BuildContext context,
  required db.PhaseTtsProject project,
}) {
  var gap = project.mergeGapSeconds;
  var fadeIn = project.mergeFadeInMs.toDouble();
  var fadeOut = project.mergeFadeOutMs.toDouble();
  var autoNormalize = project.autoNormalizeLoudness;

  return showDialog<db.PhaseTtsProject>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.phaseMergeSettings),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SliderRow(
                    icon: Icons.space_bar_rounded,
                    label: l10n.phaseMergeGap,
                    valueLabel: '${gap.toStringAsFixed(2)} s',
                    value: gap,
                    min: 0,
                    max: 3,
                    divisions: 60,
                    onChanged: (v) => setDialogState(() => gap = v),
                  ),
                  _Hint(l10n.phaseMergeGapHint),
                  const SizedBox(height: 14),
                  _SliderRow(
                    icon: Icons.trending_up_rounded,
                    label: l10n.phaseFadeIn,
                    valueLabel: '${fadeIn.round()} ms',
                    value: fadeIn,
                    min: 0,
                    max: 300,
                    divisions: 60,
                    onChanged: (v) => setDialogState(() => fadeIn = v),
                  ),
                  _SliderRow(
                    icon: Icons.trending_down_rounded,
                    label: l10n.phaseFadeOut,
                    valueLabel: '${fadeOut.round()} ms',
                    value: fadeOut,
                    min: 0,
                    max: 800,
                    divisions: 80,
                    onChanged: (v) => setDialogState(() => fadeOut = v),
                  ),
                  _Hint(l10n.phaseFadeHint),
                  const SizedBox(height: 8),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoNormalize,
                    onChanged: (v) => setDialogState(() => autoNormalize = v),
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: Text(l10n.loudnessAutoTitle),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                project.copyWith(
                  mergeGapSeconds: double.parse(gap.toStringAsFixed(2)),
                  mergeFadeInMs: fadeIn.round(),
                  mergeFadeOutMs: fadeOut.round(),
                  autoNormalizeLoudness: autoNormalize,
                ),
              ),
              child: Text(l10n.uiSave),
            ),
          ],
        );
      },
    ),
  );
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.55)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
  );
}
