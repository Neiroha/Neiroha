import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';

class ProjectSettingsResult {
  final String name;
  final String bankId;
  final bool autoNormalizeLoudness;
  final bool deleteRequested;

  const ProjectSettingsResult({
    required this.name,
    required this.bankId,
    required this.autoNormalizeLoudness,
    this.deleteRequested = false,
  });
}

Future<ProjectSettingsResult?> showProjectSettingsDialog({
  required BuildContext context,
  required String projectName,
  required String bankId,
  required List<db.VoiceBank> banks,
  required bool autoNormalizeLoudness,
}) {
  final nameCtrl = TextEditingController(text: projectName);
  final bankIds = banks.map((bank) => bank.id).toSet();
  String? selectedBankId = bankIds.contains(bankId)
      ? bankId
      : (banks.isEmpty ? null : banks.first.id);
  var autoNormalize = autoNormalizeLoudness;
  String? error;

  return showDialog<ProjectSettingsResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final l10n = AppLocalizations.of(context);
        final bank = banks.where((b) => b.id == selectedBankId).firstOrNull;
        return AlertDialog(
          title: Text(l10n.uiProjectSettings),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.uiProjectName,
                      errorText: error,
                    ),
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: l10n.uiVoiceBank),
                    isExpanded: true,
                    initialValue: selectedBankId,
                    items: [
                      for (final bank in banks)
                        DropdownMenuItem(
                          value: bank.id,
                          child: Text(bank.name),
                        ),
                    ],
                    onChanged: banks.isEmpty
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => selectedBankId = value);
                            }
                          },
                  ),
                  SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: autoNormalize,
                    onChanged: (v) => setDialogState(() => autoNormalize = v),
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: Text(l10n.loudnessAutoTitle),
                    subtitle: Text(
                      l10n.loudnessAutoHint(
                        (bank?.loudnessTargetLufs ?? -16).toStringAsFixed(1),
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(
                ctx,
                ProjectSettingsResult(
                  name: projectName,
                  bankId: selectedBankId ?? bankId,
                  autoNormalizeLoudness: autoNormalizeLoudness,
                  deleteRequested: true,
                ),
              ),
              icon: const Icon(Icons.delete_rounded, size: 16),
              label: Text(l10n.uiDelete),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = l10n.uiNameIsRequired);
                  return;
                }
                Navigator.pop(
                  ctx,
                  ProjectSettingsResult(
                    name: name,
                    bankId: selectedBankId ?? bankId,
                    autoNormalizeLoudness: autoNormalize,
                  ),
                );
              },
              child: Text(l10n.uiSave),
            ),
          ],
        );
      },
    ),
  ).whenComplete(nameCtrl.dispose);
}
