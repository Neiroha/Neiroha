import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverRunning = ref.watch(serverRunningProvider);
    final startup = ref.watch(storageStartupProvider);

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

        _SectionHeader(title: 'STORAGE'),
        const SizedBox(height: 8),
        _StorageCard(startup: startup),
        const SizedBox(height: 24),

        _SectionHeader(title: 'ABOUT'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'Neiroha',
              subtitle: 'v0.1.0 — AI Audio Middleware & Dubbing Workstation',
              trailing: const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Storage card ─────────────────────────────

class _StorageCard extends ConsumerWidget {
  const _StorageCard({required this.startup});

  final AsyncValue<StorageScanReport> startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = PathService.instance;
    final dataRoot = paths.dataRoot.path;
    final voiceAssetRoot = paths.voiceAssetRoot.path;
    final isDefault =
        paths.voiceAssetRoot.path == paths.defaultVoiceAssetRoot.path;
    final missing = startup.maybeWhen(
      data: (r) => r.missing,
      orElse: () => 0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettingsRow(
              icon: Icons.storage_rounded,
              title: 'Data Directory',
              subtitle: '$dataRoot\n'
                  '${paths.isPortable ? 'Portable (next to executable)' : 'App-support fallback (install dir is read-only)'}',
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy path',
                onPressed: () => Clipboard.setData(ClipboardData(text: dataRoot)),
              ),
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.folder_open_rounded,
              title: 'Voice Asset Directory',
              subtitle: '$voiceAssetRoot\n'
                  '${isDefault ? 'Default location' : 'Custom location'}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDefault)
                    TextButton(
                      onPressed: () => _resetRoot(context, ref),
                      child: const Text('Reset'),
                    ),
                  TextButton(
                    onPressed: () => _pickRoot(context, ref),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const Divider(),
            _SettingsRow(
              icon: missing > 0
                  ? Icons.warning_amber_rounded
                  : Icons.sync_rounded,
              title: 'Sync with Disk',
              subtitle: startup.when(
                data: (r) => missing > 0
                    ? '$missing archived file(s) are missing on disk — rows flagged, not deleted.'
                    : 'All ${r.checked} archived file(s) are present.',
                loading: () => 'Scanning…',
                error: (e, _) => 'Scan failed: $e',
              ),
              trailing: startup.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => _manualSync(context, ref),
                      child: const Text('Scan Now'),
                    ),
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.delete_forever_rounded,
              title: 'Clear All Archived Audio',
              subtitle:
                  'Deletes every generated take + imported reference audio. '
                  'Projects, characters, banks are preserved.',
              trailing: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => _clearAll(context, ref),
                child: const Text('Clear…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRoot(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose voice asset directory',
    );
    if (picked == null || picked.isEmpty) return;
    final storage = ref.read(storageServiceProvider);
    try {
      await storage.setVoiceAssetRoot(picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not use that folder: $e')),
        );
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice asset directory set to $picked')),
      );
    }
  }

  Future<void> _resetRoot(BuildContext context, WidgetRef ref) async {
    await ref.read(storageServiceProvider).setVoiceAssetRoot(null);
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice asset directory reset to default')),
      );
    }
  }

  Future<void> _manualSync(BuildContext context, WidgetRef ref) async {
    ref.invalidate(storageStartupProvider);
    final report = await ref.read(storageStartupProvider.future);
    if (!context.mounted) return;
    final msg = report.missing == 0
        ? 'Scan complete — all ${report.checked} file(s) present.'
        : 'Scan complete — ${report.missing} missing of ${report.checked}.${report.recovered > 0 ? ' ${report.recovered} recovered.' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final usage = await storage.measureVoiceAssetRoot();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ClearAudioDialog(usage: usage),
    );
    if (confirmed != true) return;
    try {
      await storage.clearAllAudioArchives();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear failed: $e')),
        );
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archived audio cleared.')),
      );
    }
  }
}

// ─────────────────── Clear-all double confirmation dialog ──────────────────

class _ClearAudioDialog extends StatefulWidget {
  const _ClearAudioDialog({required this.usage});

  final StorageUsage usage;

  @override
  State<_ClearAudioDialog> createState() => _ClearAudioDialogState();
}

class _ClearAudioDialogState extends State<_ClearAudioDialog> {
  final _confirmCtrl = TextEditingController();
  bool _acknowledged = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Case-sensitive: label reads "Type CLEAR" and the whole point of the
    // ceremony is to stop autopilot confirmations.
    final canConfirm = _acknowledged && _confirmCtrl.text.trim() == 'CLEAR';
    return AlertDialog(
      title: const Text('Clear all archived audio?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will delete ${widget.usage.fileCount} file(s) '
            '(${widget.usage.prettyBytes}) from disk and wipe:\n'
            ' • Quick TTS history\n'
            ' • Generated takes on Phase/Dialog project lines\n'
            ' • Voice asset library (reference audio)\n'
            ' • Timeline clips\n\n'
            'Your projects, characters, providers, and scripts are preserved.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              const Expanded(
                child: Text('I understand this cannot be undone.'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(
              labelText: "Type CLEAR to confirm",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          child: const Text('Clear Audio'),
        ),
      ],
    );
  }
}

// ─────────────────────────── Shared widgets ───────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: AppTheme.accentColor),
          ),
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
