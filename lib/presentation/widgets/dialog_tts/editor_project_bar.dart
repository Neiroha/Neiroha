import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Header bar above the Dialog TTS editor: back button, project icon and
/// name, and a small badge showing how many voices the bank contains.
class EditorProjectBar extends StatelessWidget {
  final db.DialogTtsProject project;
  final int voiceCount;
  final VoidCallback onClose;

  const EditorProjectBar({
    super.key,
    required this.project,
    required this.voiceCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).uiBackToProjects,
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          SizedBox(width: 4),
          Icon(Icons.forum_rounded, color: AppTheme.accentColor, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              project.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$voiceCount voices',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
