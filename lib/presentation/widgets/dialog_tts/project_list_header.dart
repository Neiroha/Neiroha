import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';

/// Top strip of the Dialog TTS list view: title, subtitle, and the
/// `New Project` action.
class ProjectListHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const ProjectListHeader({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PageHeader(
      icon: Icons.forum_rounded,
      title: l10n.navDialogTts,
      subtitle: l10n.uiMultiCharacterConversations,
      actions: [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.uiNewProject),
        ),
      ],
    );
  }
}
