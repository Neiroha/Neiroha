import 'package:flutter/material.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';

/// A voice shown as a chip; [id] is set when the voice can be removed.
typedef VoiceChipEntry = ({String label, String? id});

/// Voice chips with a filter box once the list gets long (Azure lists
/// hundreds), capped so a huge list never builds thousands of chips.
class VoiceChipList extends StatefulWidget {
  const VoiceChipList({super.key, required this.voices, this.onDelete});
  final List<VoiceChipEntry> voices;
  final ValueChanged<String>? onDelete;

  static const _filterFrom = 24;
  static const _cap = 120;

  @override
  State<VoiceChipList> createState() => _VoiceChipListState();
}

class _VoiceChipListState extends State<VoiceChipList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.voices
        : widget.voices
              .where((v) => v.label.toLowerCase().contains(q))
              .toList();
    final shown = matches.take(VoiceChipList._cap).toList();
    final style = TextStyle(
      fontSize: 11,
      color: Colors.white.withValues(alpha: 0.7),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.voices.length > VoiceChipList._filterFrom)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                hintText: l.voiceFilterHint,
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final v in shown)
              Container(
                padding: EdgeInsets.only(
                  left: 8,
                  right: v.id != null && widget.onDelete != null ? 2 : 8,
                  top: 3,
                  bottom: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.label, style: style),
                    if (v.id != null && widget.onDelete != null)
                      InkWell(
                        onTap: () => widget.onDelete!(v.id!),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.close_rounded, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (matches.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.voiceMoreHidden(matches.length - shown.length),
              style: style.copyWith(color: Colors.white38),
            ),
          ),
      ],
    );
  }
}

/// A collapsible row holding a group of voices: one TTS engine without
/// models (Azure, the OS voice) or a provider's account / custom voices.
class VoiceGroupRow extends StatefulWidget {
  const VoiceGroupRow({
    super.key,
    required this.title,
    required this.voices,
    this.icon = Icons.record_voice_over_rounded,
    this.onDelete,
  });
  final String title;
  final IconData icon;
  final List<VoiceChipEntry> voices;
  final ValueChanged<String>? onDelete;

  @override
  State<VoiceGroupRow> createState() => _VoiceGroupRowState();
}

class _VoiceGroupRowState extends State<VoiceGroupRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 16,
                      color: Colors.tealAccent.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    VoiceCountBadge(count: widget.voices.length),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 2, 12, 8),
                child: VoiceChipList(
                  voices: widget.voices,
                  onDelete: widget.onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VoiceCountBadge extends StatelessWidget {
  const VoiceCountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      AppLocalizations.of(context).uiVoiceCount(count),
      style: TextStyle(
        fontSize: 10,
        color: Colors.white.withValues(alpha: 0.55),
      ),
    ),
  );
}
