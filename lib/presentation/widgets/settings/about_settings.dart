import 'package:flutter/material.dart';

import 'settings_shared.dart';

class AboutSettingsCard extends StatelessWidget {
  const AboutSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SettingsRow(
          icon: Icons.info_outline_rounded,
          title: 'Neiroha',
          subtitle: 'v0.1.0 - AI Audio Middleware & Dubbing Workstation',
        ),
      ),
    );
  }
}
