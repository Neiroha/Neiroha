import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';

class ProjectSettingsResult {
  final String name;
  final String bankId;
  final bool deleteRequested;

  const ProjectSettingsResult({
    required this.name,
    required this.bankId,
    this.deleteRequested = false,
  });
}

Future<ProjectSettingsResult?> showProjectSettingsDialog({
  required BuildContext context,
  required String projectName,
  required String bankId,
  required List<db.VoiceBank> banks,
}) {
  final nameCtrl = TextEditingController(text: projectName);
  final bankIds = banks.map((bank) => bank.id).toSet();
  String? selectedBankId = bankIds.contains(bankId)
      ? bankId
      : (banks.isEmpty ? null : banks.first.id);
  String? error;

  return showDialog<ProjectSettingsResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(AppLocalizations.of(context).uiProjectSettings),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiProjectName,
                  errorText: error,
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiVoiceBank,
                ),
                isExpanded: true,
                initialValue: selectedBankId,
                items: [
                  for (final bank in banks)
                    DropdownMenuItem(value: bank.id, child: Text(bank.name)),
                ],
                onChanged: banks.isEmpty
                    ? null
                    : (value) {
                        if (value != null) selectedBankId = value;
                      },
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(
              ctx,
              ProjectSettingsResult(
                name: projectName,
                bankId: selectedBankId ?? bankId,
                deleteRequested: true,
              ),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: Text(AppLocalizations.of(context).uiDelete),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setDialogState(
                  () => error = AppLocalizations.of(context).uiNameIsRequired,
                );
                return;
              }
              Navigator.pop(
                ctx,
                ProjectSettingsResult(
                  name: name,
                  bankId: selectedBankId ?? bankId,
                ),
              );
            },
            child: Text(AppLocalizations.of(context).uiSave),
          ),
        ],
      ),
    ),
  ).whenComplete(nameCtrl.dispose);
}
