import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Result of [showCreatePhaseTtsProjectDialog].
class CreatePhaseProjectResult {
  final String name;
  final String bankId;
  const CreatePhaseProjectResult({required this.name, required this.bankId});
}

/// Prompts the user for a name and Voice Bank when creating a new Phase
/// TTS project. Returns `null` if the user cancels or the name is blank
/// after trimming. Caller must ensure [banks] is non-empty.
Future<CreatePhaseProjectResult?> showCreatePhaseTtsProjectDialog({
  required BuildContext context,
  required List<db.VoiceBank> banks,
}) async {
  final nameCtrl = TextEditingController();
  String selectedBankId = banks.first.id;

  try {
    final result = await showDialog<CreatePhaseProjectResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).uiNewPhaseTTSProject),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).uiProjectName,
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).navVoiceBank,
                ),
                isExpanded: true,
                initialValue: selectedBankId,
                items: banks
                    .map(
                      (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedBankId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                CreatePhaseProjectResult(
                  name: nameCtrl.text,
                  bankId: selectedBankId,
                ),
              ),
              child: Text(AppLocalizations.of(context).uiCreate),
            ),
          ],
        ),
      ),
    );
    if (result == null) return null;
    final trimmed = result.name.trim();
    if (trimmed.isEmpty) return null;
    return CreatePhaseProjectResult(name: trimmed, bankId: result.bankId);
  } finally {
    nameCtrl.dispose();
  }
}
