import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class PhaseSpeakerLabel extends StatelessWidget {
  const PhaseSpeakerLabel({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Text(switch (label!) {
      'narrator' => l.roleNarrator,
      'system' => l.roleSystem,
      'dialogue' || 'thought' => l.phaseRoleUnknown,
      _ => label!,
    }, style: Theme.of(context).textTheme.labelSmall);
  }
}
