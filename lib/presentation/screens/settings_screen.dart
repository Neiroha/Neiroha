import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:q_vox_lab/providers/app_providers.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverRunning = ref.watch(serverRunningProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),

        // Server section
        _SectionHeader(title: 'API SERVER'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.power_settings_new_rounded,
                  title: 'API Server',
                  subtitle: serverRunning
                      ? 'Running on port ${ref.read(apiServerProvider).port}'
                      : 'Stopped',
                  trailing: Switch(
                    value: serverRunning,
                    onChanged: (value) async {
                      final server = ref.read(apiServerProvider);
                      if (value) {
                        await server.start();
                      } else {
                        await server.stop();
                      }
                      ref.read(serverRunningProvider.notifier).state = value;
                    },
                  ),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.numbers_rounded,
                  title: 'Port',
                  subtitle: '${ref.read(apiServerProvider).port}',
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // General section
        _SectionHeader(title: 'GENERAL'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.folder_open_rounded,
                  title: 'Output Directory',
                  subtitle: 'Default (app support)',
                  trailing: TextButton(
                    onPressed: () {
                      // TODO: pick directory
                    },
                    child: const Text('Change'),
                  ),
                ),
                const Divider(),
                _SettingsRow(
                  icon: Icons.audio_file_rounded,
                  title: 'Default Audio Format',
                  subtitle: 'MP3',
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // About section
        _SectionHeader(title: 'ABOUT'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'Q-Vox-Lab',
              subtitle: 'v0.1.0 — AI Audio Middleware & Dubbing Workstation',
              trailing: const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
