import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/project_creation_dialog.dart';

/// Result of [showCreateDialogTtsProjectDialog].
class CreateDialogProjectResult {
  final String name;
  final String bankId;
  const CreateDialogProjectResult({required this.name, required this.bankId});
}

/// Prompts the user for a name and Voice Bank when creating a new Dialog
/// TTS project. Returns `null` if the user cancels or the name is blank
/// after trimming. Caller must ensure [banks] is non-empty.
Future<CreateDialogProjectResult?> showCreateDialogTtsProjectDialog({
  required BuildContext context,
  required List<db.VoiceBank> banks,
}) async {
  final result = await showProjectCreationDialog(
    context: context,
    title: AppLocalizations.of(context).uiNewDialogTTSProject,
    banks: banks,
  );
  return result == null
      ? null
      : CreateDialogProjectResult(name: result.name, bankId: result.bankId);
}
