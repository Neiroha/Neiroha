import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Top strip of the Phase TTS list view: title, subtitle, and the
/// `New Project` action.
class ProjectListHeader extends StatelessWidget {
  final VoidCallback onCreate;

  const ProjectListHeader({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).navPhaseTts,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Text(
            AppLocalizations.of(context).uiNovelLongFormNarration,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppLocalizations.of(context).uiNewProject),
          ),
        ],
      ),
    );
  }
}
