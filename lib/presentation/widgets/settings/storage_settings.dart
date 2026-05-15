import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

// ───────────────────────────── Storage card ─────────────────────────────

class StorageSettingsCard extends ConsumerWidget {
  const StorageSettingsCard({super.key, required this.startup});

  final AsyncValue<StorageScanReport> startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = PathService.instance;
    final dataRoot = paths.dataRoot.path;
    final voiceAssetRoot = paths.voiceAssetRoot.path;
    final isDefault =
        paths.voiceAssetRoot.path == paths.defaultVoiceAssetRoot.path;
    final missing = startup.maybeWhen(data: (r) => r.missing, orElse: () => 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SettingsRow(
              icon: Icons.storage_rounded,
              title: AppLocalizations.of(context).uiDataDirectory,
              subtitle:
                  '$dataRoot\n'
                  '${paths.isPortable ? AppLocalizations.of(context).uiPortableNextToExecutable : AppLocalizations.of(context).uiAppSupportFallbackInstallDirIsReadOnly}',
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: AppLocalizations.of(context).uiCopyPath,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: dataRoot)),
              ),
            ),
            const Divider(),
            SettingsRow(
              icon: Icons.folder_open_rounded,
              title: AppLocalizations.of(context).uiVoiceAssetDirectory,
              subtitle:
                  '$voiceAssetRoot\n'
                  '${isDefault ? AppLocalizations.of(context).uiDefaultLocation : AppLocalizations.of(context).uiCustomLocation}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDefault)
                    TextButton(
                      onPressed: () => _resetRoot(context, ref),
                      child: Text(AppLocalizations.of(context).uiReset),
                    ),
                  TextButton(
                    onPressed: () => _pickRoot(context, ref),
                    child: Text(AppLocalizations.of(context).uiChange),
                  ),
                ],
              ),
            ),
            const Divider(),
            SettingsRow(
              icon: missing > 0
                  ? Icons.warning_amber_rounded
                  : Icons.sync_rounded,
              title: AppLocalizations.of(context).uiSyncWithDisk,
              subtitle: startup.when(
                data: (r) => missing > 0
                    ? AppLocalizations.of(
                        context,
                      ).uiArchivedFileSAreMissingOnDiskRowsFlaggedNotDeleted(
                        missing,
                      )
                    : AppLocalizations.of(
                        context,
                      ).uiAllArchivedFileSArePresent(r.checked),
                loading: () => AppLocalizations.of(context).uiScanning,
                error: (e, _) => AppLocalizations.of(context).uiScanFailed(e),
              ),
              trailing: startup.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => _manualSync(context, ref),
                      child: Text(AppLocalizations.of(context).uiScanNow),
                    ),
            ),
            const Divider(),
            SettingsRow(
              icon: Icons.delete_forever_rounded,
              title: AppLocalizations.of(context).uiClearAllArchivedAudio,
              subtitle: AppLocalizations.of(context).uiText,
              trailing: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => _clearAll(context, ref),
                child: Text(AppLocalizations.of(context).uiClear2),
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context).uiCouldNotUseThatFolder(e),
            ),
          ),
        );
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiVoiceAssetDirectorySetTo(picked),
          ),
        ),
      );
    }
  }

  Future<void> _resetRoot(BuildContext context, WidgetRef ref) async {
    await ref.read(storageServiceProvider).setVoiceAssetRoot(null);
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiVoiceAssetDirectoryResetToDefault,
          ),
        ),
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
          SnackBar(
            content: Text(AppLocalizations.of(context).uiClearFailed(e)),
          ),
        );
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiArchivedAudioCleared),
        ),
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
      title: Text(AppLocalizations.of(context).uiClearAllArchivedAudio2),
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
          SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).uiIUnderstandThisCannotBeUndone,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            decoration: InputDecoration(
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
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text(AppLocalizations.of(context).uiClearAudio),
        ),
      ],
    );
  }
}
