import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// Header bar above the Phase TTS editor: back, project icon and name,
/// voice-count badge, and the editor's primary actions
/// (`Export Merged` / `Save`). The Auto-Split rule picker now lives in the
/// left workspace's toolbar so the two related controls are side by side.
class EditorProjectBar extends StatelessWidget {
  final db.PhaseTtsProject project;
  final int voiceCount;
  final bool exporting;
  final bool dirty;

  /// `null` disables the Export Merged button (no completed audio yet, or
  /// no ffmpeg available).
  final VoidCallback? onExportMerged;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const EditorProjectBar({
    super.key,
    required this.project,
    required this.voiceCount,
    required this.onClose,
    required this.onSave,
    required this.onExportMerged,
    this.exporting = false,
    this.dirty = false,
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
            child: Text(dirty ? '• ${project.name}' : project.name,
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
            onPressed: exporting ? null : onExportMerged,
            icon: exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.merge_rounded, size: 16),
            label: const Text('Export Merged'),
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
