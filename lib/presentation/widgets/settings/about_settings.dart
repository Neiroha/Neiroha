import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

import 'settings_shared.dart';

class AboutSettingsCard extends StatelessWidget {
  const AboutSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.info_outline_rounded,
          title: 'Neiroha',
          subtitle: l10n.aboutSubtitle,
        ),
      ),
    );
  }
}
