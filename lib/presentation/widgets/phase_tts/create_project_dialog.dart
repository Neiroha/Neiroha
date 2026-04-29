import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

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
          title: const Text('New Phase TTS Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Voice Bank'),
                isExpanded: true,
                initialValue: selectedBankId,
                items: banks
                    .map((b) => DropdownMenuItem(
                        value: b.id, child: Text(b.name)))
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
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(
                      ctx,
                      CreatePhaseProjectResult(
                        name: nameCtrl.text,
                        bankId: selectedBankId,
                      ),
                    ),
                child: const Text('Create')),
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
