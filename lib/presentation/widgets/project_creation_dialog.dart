import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Asks for a project name and voice bank. Requires at least one bank.
Future<({String name, String bankId})?> showProjectCreationDialog({
  required BuildContext context,
  required String title,
  required List<db.VoiceBank> banks,
}) {
  var name = '';
  var bankId = banks.first.id;
  return showDialog<({String name, String bankId})>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => name = value,
              decoration: InputDecoration(labelText: l10n.uiProjectName),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: l10n.navVoiceBank),
              isExpanded: true,
              initialValue: bankId,
              items: [
                for (final bank in banks)
                  DropdownMenuItem(value: bank.id, child: Text(bank.name)),
              ],
              onChanged: (value) => bankId = value ?? bankId,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.uiCancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = name.trim();
              Navigator.pop(
                context,
                trimmed.isEmpty ? null : (name: trimmed, bankId: bankId),
              );
            },
            child: Text(l10n.uiCreate),
          ),
        ],
      );
    },
  );
}
