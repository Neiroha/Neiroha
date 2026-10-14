import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Header bar above the Dialog TTS editor: back button, project icon and
/// name, and a small badge showing how many voices the bank contains. The
/// icon and badge drop out on narrow widths so the name keeps its room.
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

  static const _compactWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactWidth;
        return Container(
          padding: compact
              ? const EdgeInsets.fromLTRB(4, 6, 12, 6)
              : const EdgeInsets.fromLTRB(12, 10, 20, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context).uiBackToProjects,
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              if (!compact) ...[
                SizedBox(width: 4),
                Icon(
                  Icons.forum_rounded,
                  color: AppTheme.accentColor,
                  size: 18,
                ),
                SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!compact) ...[
                SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.of(context).uiVoiceCount(voiceCount),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
