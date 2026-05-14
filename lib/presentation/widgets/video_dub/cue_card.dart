import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/theme/app_theme.dart';

/// One row of the subtitle panel in the Video Dub editor.
///
/// Stateless; the parent owns selection / generating / preview flags and
/// wires the row's actions back through the callbacks.
class CueCard extends StatelessWidget {
  final db.SubtitleCue cue;
  final int index;
  final List<db.VoiceAsset> bankAssets;
  final bool isSelected;
  final bool isGenerating;
  final bool isPreviewing;
  final VoidCallback onTap;
  final ValueChanged<String?> onVoiceChanged;
  final VoidCallback? onGenerate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  const CueCard({
    super.key,
    required this.cue,
    required this.index,
    required this.bankAssets,
    required this.isSelected,
    required this.isGenerating,
    required this.isPreviewing,
    required this.onTap,
    required this.onVoiceChanged,
    required this.onGenerate,
    required this.onEdit,
    required this.onDelete,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final bankHasVoice = bankAssets.any((a) => a.id == cue.voiceAssetId);
    final canGenerate =
        cue.voiceAssetId != null && bankHasVoice && !isGenerating;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isSelected ? AppTheme.accentColor.withValues(alpha: 0.16) : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_ms(cue.startMs)} → ${_ms(cue.endMs)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (isGenerating)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (cue.error != null)
                    Tooltip(
                      message: cue.error!,
                      child: const Icon(
                        Icons.error_rounded,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                    )
                  else if (cue.audioPath != null)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      icon: Icon(
                        isPreviewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 16,
                      ),
                      tooltip: 'Preview',
                      onPressed: onPreview,
                    )
                  else
                    Icon(
                      Icons.pending_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    icon: Icon(
                      cue.audioPath != null
                          ? Icons.refresh_rounded
                          : Icons.auto_awesome_rounded,
                      size: 14,
                      color: canGenerate
                          ? AppTheme.accentColor
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                    tooltip: cue.audioPath != null ? 'Regenerate' : 'Generate',
                    onPressed: canGenerate ? onGenerate : null,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                cue.cueText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: 'Voice',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  isExpanded: true,
                  initialValue: bankHasVoice ? cue.voiceAssetId : null,
                  items: bankAssets
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onVoiceChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ms(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    final msR = d.inMilliseconds.remainder(1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(m)}:${two(s)}.${msR.toString().padLeft(3, '0')}';
  }
}
