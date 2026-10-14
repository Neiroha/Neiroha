import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Labelled slider row shared by the loudness settings.
class _LoudnessSlider extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _LoudnessSlider({
    required this.icon,
    required this.label,
    required this.hint,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
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
          divisions: ((max - min) * 2).round(),
          label: valueLabel,
          onChanged: onChanged,
        ),
        Text(
          hint,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

/// Per-character offset on top of the bank's loudness target.
class CharacterLoudnessOffsetField extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const CharacterLoudnessOffsetField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sign = value > 0 ? '+' : '';
    return _LoudnessSlider(
      icon: Icons.graphic_eq_rounded,
      label: l10n.loudnessCharacterOffset,
      hint: l10n.loudnessCharacterOffsetHint,
      valueLabel: '$sign${value.toStringAsFixed(1)} dB',
      value: value,
      min: -12,
      max: 12,
      onChanged: onChanged,
    );
  }
}

/// Base loudness target of a voice bank.
class BankLoudnessTargetField extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const BankLoudnessTargetField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _LoudnessSlider(
      icon: Icons.graphic_eq_rounded,
      label: l10n.loudnessBankTarget,
      hint: l10n.loudnessBankTargetHint,
      valueLabel: '${value.toStringAsFixed(1)} LUFS',
      value: value,
      min: -30,
      max: -10,
      onChanged: onChanged,
    );
  }
}
