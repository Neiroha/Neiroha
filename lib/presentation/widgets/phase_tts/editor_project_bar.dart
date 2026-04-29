import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Header bar above the Phase TTS editor: back, project icon and name,
/// voice-count badge, and `Auto Split` / `Save` actions.
class EditorProjectBar extends StatelessWidget {
  final db.PhaseTtsProject project;
  final int voiceCount;
  final VoidCallback onClose;
  final VoidCallback onAutoSplit;
  final VoidCallback onSave;

  const EditorProjectBar({
    super.key,
    required this.project,
    required this.voiceCount,
    required this.onClose,
    required this.onAutoSplit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to projects',
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 4),
          Icon(Icons.auto_stories_rounded,
              color: AppTheme.accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$voiceCount voices',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: onAutoSplit,
            icon: const Icon(Icons.splitscreen_rounded, size: 16),
            label: const Text('Auto Split'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
