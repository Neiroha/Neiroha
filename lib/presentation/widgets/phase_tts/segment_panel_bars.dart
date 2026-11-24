part of 'segment_voice_panel.dart';

/// Toolbar and multi-select bar above the segment list.
extension _SegmentPanelBars on _SegmentVoicePanelState {
  Widget _buildToolbar(
    AppLocalizations l10n,
    List<db.PhaseTtsSegment> ordered, {
    required int doneCount,
    required int queuedCount,
    required List<db.PhaseTtsSegment> failed,
  }) {
    final assetIds = widget.bankAssets.map((asset) => asset.id).toSet();
    final bulkValue = _bulkVoiceId != null && assetIds.contains(_bulkVoiceId)
        ? _bulkVoiceId
        : null;
    final canGenerateAll =
        queuedCount > 0 &&
        widget.bankAssets.isNotEmpty &&
        !widget.generatingAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.generatingAll)
                FilledButton.tonalIcon(
                  onPressed: widget.onCancelGenerate,
                  icon: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text(l10n.phaseStopGenerating),
                )
              else
                FilledButton.icon(
                  onPressed: canGenerateAll ? widget.onGenerateAll : null,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(
                    queuedCount > 0
                        ? l10n.uiGenerateAll2(queuedCount)
                        : l10n.uiGenerateAll,
                  ),
                ),
              if (failed.isNotEmpty && !widget.generatingAll)
                OutlinedButton.icon(
                  onPressed: widget.onGenerateMany == null
                      ? null
                      : () => unawaited(
                          _generateMany(
                            failed
                                .where((s) => s.voiceAssetId != null)
                                .toList(),
                          ),
                        ),
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(l10n.phaseRetryFailed(failed.length)),
                ),
              OutlinedButton.icon(
                onPressed: doneCount > 0 ? widget.onPlayAll : null,
                icon: const Icon(Icons.playlist_play_rounded, size: 18),
                label: Text(l10n.phasePlayAll),
              ),
              Tooltip(
                message: l10n.loudnessActionTooltip,
                child: OutlinedButton.icon(
                  onPressed: doneCount > 0 ? widget.onNormalize : null,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 16),
                  label: Text(l10n.loudnessAction),
                ),
              ),
              IconButton(
                tooltip: l10n.phaseSelectMode,
                onPressed: ordered.isEmpty ? null : () => _setSelecting(true),
                icon: const Icon(Icons.checklist_rounded, size: 20),
              ),
              IconButton(
                tooltip: l10n.phaseAddSegment,
                onPressed: () => unawaited(
                  _openInsertDialog(ordered.isEmpty ? null : ordered.last),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: _VoiceDropdown(
                    value: bulkValue,
                    assets: widget.bankAssets,
                    hintText: l10n.uiVoiceForAll,
                    onChanged: (id) => _update(() => _bulkVoiceId = id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: ordered.isEmpty
                    ? null
                    : () => unawaited(_applyBulkVoice(ordered)),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: Text(l10n.phaseApplyVoiceToAll),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(
    AppLocalizations l10n,
    List<db.PhaseTtsSegment> ordered,
    List<int> visible,
  ) {
    final chosen = [
      for (final s in ordered)
        if (_selected.contains(s.id)) s,
    ];
    final none = chosen.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Text(
            l10n.phaseSelectedCount(chosen.length),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => _update(
              () => _selected.addAll(visible.map((i) => ordered[i].id)),
            ),
            child: Text(l10n.phaseSelectAll),
          ),
          PopupMenuButton<String>(
            enabled: !none,
            tooltip: l10n.phaseAssignVoice,
            onSelected: (id) {
              final voiceId = id.isEmpty ? null : id;
              for (final s in chosen) {
                _changeSegmentVoice(s, voiceId);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: '', child: Text(l10n.uiUnassigned)),
              for (final a in widget.bankAssets)
                PopupMenuItem(value: a.id, child: Text(a.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    size: 16,
                    color: none ? Colors.white24 : AppTheme.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.phaseAssignVoice,
                    style: TextStyle(
                      fontSize: 13,
                      color: none ? Colors.white38 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.phaseRegenerateSelected,
            onPressed: none || widget.onGenerateMany == null
                ? null
                : () => unawaited(
                    _generateMany(
                      chosen.where((s) => s.voiceAssetId != null).toList(),
                    ),
                  ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          IconButton(
            tooltip: l10n.phaseDeleteSelected,
            onPressed: none ? null : () => _delete(chosen),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: _failedColor,
            ),
          ),
          IconButton(
            tooltip: l10n.phaseExitSelect,
            onPressed: () => _setSelecting(false),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final int total;
  final int done;
  final int failed;
  final int unassigned;
  final double totalSeconds;

  const _PanelHeader({
    required this.total,
    required this.done,
    required this.failed,
    required this.unassigned,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Colors.white.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.uiSEGMENTS,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    Text(
                      l10n.phaseStatsGenerated(done, total),
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    if (totalSeconds > 0)
                      Text(
                        _formatClock(totalSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (failed > 0)
                      Text(
                        l10n.phaseStatsFailed(failed),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _failedColor,
                        ),
                      ),
                    if (unassigned > 0)
                      Text(
                        l10n.phaseStatsUnassigned(unassigned),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                        ),
                      ),
                  ],
                ),
              ),
              Tooltip(
                message: l10n.phaseShortcuts,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.keyboard_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  color: done == total ? _doneColor : AppTheme.accentColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
