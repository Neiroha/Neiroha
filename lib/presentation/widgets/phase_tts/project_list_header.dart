import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';

String? phaseScriptPreview(String scriptText) {
  final trimmed = scriptText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
}

/// Top strip of the Phase TTS list view: title, subtitle, and the
/// `New Project` action.
class ProjectListHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const ProjectListHeader({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PageHeader(
      icon: Icons.auto_stories_rounded,
      title: l10n.navPhaseTts,
      subtitle: l10n.uiNovelLongFormNarration,
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
