part of '../../screens/novel_reader_screen.dart';

class _NovelSettingsPane extends StatelessWidget {
  final db.NovelProject project;
  final List<db.VoiceAsset> bankAssets;
  final List<db.NovelSegment> segments;
  final Set<String> generatingSegmentIds;
  final bool importing;
  final bool exporting;
  final bool hasAudio;
  final bool generatingAll;
  final bool editing;
  final bool cacheComplete;
  final bool cacheOnlyPlayback;
  final ValueChanged<String?> onNarratorChanged;
  final ValueChanged<String?> onDialogueChanged;
  final ValueChanged<bool> onAutoTurnPageChanged;
  final ValueChanged<bool> onAutoAdvanceChaptersChanged;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<bool> onAutoSliceChanged;
  final ValueChanged<bool> onSliceOnlyAtPunctuationChanged;
  final ValueChanged<int> onMaxSliceCharsChanged;
  final ValueChanged<int> onPrefetchSegmentsChanged;
  final ValueChanged<double> onPlaybackGapChanged;
  final ValueChanged<bool> onOverwriteWhilePlayingChanged;
  final ValueChanged<bool> onCacheOnlyPlaybackChanged;
  final ValueChanged<bool> onSkipPunctuationOnlyChanged;
  final VoidCallback onManageDialogueRules;
  final VoidCallback onManageTextFilters;
  final ValueChanged<String> onCacheCurrentColorChanged;
  final ValueChanged<String> onCacheStaleColorChanged;
  final ValueChanged<double> onCacheHighlightOpacityChanged;
  final VoidCallback? onGenerateAll;
  final VoidCallback? onExport;
  final VoidCallback? onNormalize;

  const _NovelSettingsPane({
    required this.project,
    required this.bankAssets,
    required this.segments,
    required this.generatingSegmentIds,
    required this.importing,
    required this.exporting,
    required this.hasAudio,
    required this.generatingAll,
    required this.editing,
    required this.cacheComplete,
    required this.cacheOnlyPlayback,
    required this.onNarratorChanged,
    required this.onDialogueChanged,
    required this.onAutoTurnPageChanged,
    required this.onAutoAdvanceChaptersChanged,
    required this.onEditingChanged,
    required this.onAutoSliceChanged,
    required this.onSliceOnlyAtPunctuationChanged,
    required this.onMaxSliceCharsChanged,
    required this.onPrefetchSegmentsChanged,
    required this.onPlaybackGapChanged,
    required this.onOverwriteWhilePlayingChanged,
    required this.onCacheOnlyPlaybackChanged,
    required this.onSkipPunctuationOnlyChanged,
    required this.onManageDialogueRules,
    required this.onManageTextFilters,
    required this.onCacheCurrentColorChanged,
    required this.onCacheStaleColorChanged,
    required this.onCacheHighlightOpacityChanged,
    required this.onGenerateAll,
    required this.onExport,
    required this.onNormalize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.panel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          _PanelTitle(AppLocalizations.of(context).uiVOICES),
          _VoiceDropdown(
            value: project.narratorVoiceAssetId,
            assets: bankAssets,
            label: AppLocalizations.of(context).uiNarrator,
            onChanged: onNarratorChanged,
          ),
          SizedBox(height: 10),
          _VoiceDropdown(
            value: project.dialogueVoiceAssetId,
            assets: bankAssets,
            label: AppLocalizations.of(context).uiDialogue,
            onChanged: onDialogueChanged,
          ),
          SizedBox(height: 18),
          _PanelTitle(AppLocalizations.of(context).uiEDIT),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiEditNovelText,
            value: editing,
            onChanged: onEditingChanged,
          ),
          SizedBox(height: 18),
          _PanelTitle(AppLocalizations.of(context).uiCACHE),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiAutoSliceLongSegments,
            value: project.autoSliceLongSegments,
            onChanged: onAutoSliceChanged,
          ),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiSliceAfterPunctuation,
            value: project.sliceOnlyAtPunctuation,
            onChanged: onSliceOnlyAtPunctuationChanged,
          ),
          _SliderSetting(
            label: AppLocalizations.of(context).uiSlice,
            value: project.maxSliceChars.clamp(20, 80).toDouble(),
            min: 20,
            max: 80,
            divisions: 12,
            valueLabel: '${project.maxSliceChars.clamp(20, 80)}',
            onChanged: (v) => onMaxSliceCharsChanged(v.round()),
          ),
          SizedBox(height: 6),
          _CacheColorRow(
            currentLabel: AppLocalizations.of(context).uiCurrent,
            currentValue: project.cacheCurrentColor,
            currentFallback: const Color(0xFF2F6B54),
            onCurrentChanged: onCacheCurrentColorChanged,
            changedLabel: AppLocalizations.of(context).uiChanged,
            changedValue: project.cacheStaleColor,
            changedFallback: const Color(0xFF7A5A2A),
            onChangedChanged: onCacheStaleColorChanged,
          ),
          _SliderSetting(
            label: AppLocalizations.of(context).uiAlpha,
            value: project.cacheHighlightOpacity.clamp(0.0, 0.24).toDouble(),
            min: 0,
            max: 0.24,
            divisions: 12,
            valueLabel:
                '${(project.cacheHighlightOpacity.clamp(0.0, 0.24) * 100).round()}%',
            onChanged: onCacheHighlightOpacityChanged,
          ),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiOverwriteWhileReading,
            value: project.overwriteCacheWhilePlaying,
            onChanged: onOverwriteWhilePlayingChanged,
          ),
          _CompactSwitch(
            label: AppLocalizations.of(context).novelPureReadingMode,
            value: cacheOnlyPlayback,
            onChanged: cacheComplete ? onCacheOnlyPlaybackChanged : null,
          ),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiSkipPunctuationOnlyText,
            value: project.skipPunctuationOnlySegments,
            onChanged: onSkipPunctuationOnlyChanged,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManageDialogueRules,
                  icon: const Icon(Icons.rule_rounded, size: 17),
                  label: Text(
                    AppLocalizations.of(context).uiDialogueRules,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManageTextFilters,
                  icon: const Icon(Icons.filter_alt_rounded, size: 17),
                  label: Text(
                    AppLocalizations.of(context).novelTextFilters,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FilledButton.icon(
            onPressed: generatingAll || importing ? null : onGenerateAll,
            icon: generatingAll
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_done_rounded, size: 17),
            label: Text(AppLocalizations.of(context).uiGenerateBook),
          ),
          SizedBox(height: 8),
          Text(
            generatingSegmentIds.isEmpty
                ? AppLocalizations.of(context).statusIdle
                : AppLocalizations.of(
                    context,
                  ).novelGeneratingSegments(generatingSegmentIds.length),
            style: TextStyle(
              fontSize: 11,
              color: context.fg.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: 18),
          _PanelTitle(AppLocalizations.of(context).sectionOutput),
          OutlinedButton.icon(
            onPressed: hasAudio && !exporting ? onExport : null,
            icon: exporting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 17),
            label: Text(AppLocalizations.of(context).uiExportBook),
          ),
          SizedBox(height: 8),
          Tooltip(
            message: AppLocalizations.of(context).loudnessActionTooltip,
            child: OutlinedButton.icon(
              onPressed: hasAudio && !exporting && !generatingAll
                  ? onNormalize
                  : null,
              icon: const Icon(Icons.graphic_eq_rounded, size: 17),
              label: Text(AppLocalizations.of(context).loudnessAction),
            ),
          ),
          SizedBox(height: 18),
          _PanelTitle(AppLocalizations.of(context).uiPLAYBACK),
          _CompactSwitch(
            label: AppLocalizations.of(context).uiAutoTurnPageWhilePlaying,
            value: project.autoTurnPage,
            onChanged: onAutoTurnPageChanged,
          ),
          _CompactSwitch(
            label: AppLocalizations.of(
              context,
            ).uiAutoSwitchChaptersWhilePlaying,
            value: project.autoAdvanceChapters,
            onChanged: onAutoAdvanceChaptersChanged,
          ),
          _SliderSetting(
            label: AppLocalizations.of(context).uiAhead,
            value: project.prefetchSegments.clamp(0, 20).toDouble(),
            min: 0,
            max: 20,
            divisions: 20,
            valueLabel: '${project.prefetchSegments.clamp(0, 20)}',
            onChanged: (v) => onPrefetchSegmentsChanged(v.round()),
          ),
          _SliderSetting(
            label: AppLocalizations.of(context).novelPlaybackGap,
            value: project.playbackGapSeconds.clamp(0.0, 2.0).toDouble(),
            min: 0,
            max: 2,
            divisions: 20,
            valueLabel:
                '${project.playbackGapSeconds.clamp(0.0, 2.0).toStringAsFixed(1)}s',
            onChanged: (v) =>
                onPlaybackGapChanged((v * 10).roundToDouble() / 10),
          ),
        ],
      ),
    );
  }
}

class _ReaderAppearanceDialog extends StatefulWidget {
  final db.NovelProject project;

  const _ReaderAppearanceDialog({required this.project});

  @override
  State<_ReaderAppearanceDialog> createState() =>
      _ReaderAppearanceDialogState();
}

class _ReaderAppearanceDialogState extends State<_ReaderAppearanceDialog> {
  late String _theme;
  late double _fontSize;
  late double _lineHeight;

  @override
  void initState() {
    super.initState();
    _theme = widget.project.readerTheme;
    _fontSize = widget.project.fontSize;
    _lineHeight = widget.project.lineHeight;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).uiReaderAppearance2),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'comfort',
                  icon: Icon(Icons.eco_rounded, size: 16),
                  label: Text(AppLocalizations.of(context).uiComfort),
                ),
                ButtonSegment(
                  value: 'paper',
                  icon: Icon(Icons.article_rounded, size: 16),
                  label: Text(AppLocalizations.of(context).uiPaper),
                ),
                ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode_rounded, size: 16),
                  label: Text(AppLocalizations.of(context).uiDark),
                ),
              ],
              selected: {_theme},
              onSelectionChanged: (values) =>
                  setState(() => _theme = values.first),
            ),
            SizedBox(height: 18),
            _SliderSetting(
              label: AppLocalizations.of(context).uiFont,
              value: _fontSize,
              min: 16,
              max: 28,
              divisions: 12,
              onChanged: (value) => setState(() => _fontSize = value),
            ),
            _SliderSetting(
              label: AppLocalizations.of(context).uiLine,
              value: _lineHeight,
              min: 1.4,
              max: 2.1,
              divisions: 7,
              onChanged: (value) => setState(() => _lineHeight = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).uiCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ReaderAppearanceResult(
              theme: _theme,
              fontSize: _fontSize,
              lineHeight: _lineHeight,
            ),
          ),
          child: Text(AppLocalizations.of(context).uiApply),
        ),
      ],
    );
  }
}

class _ReaderAppearanceResult {
  final String theme;
  final double fontSize;
  final double lineHeight;

  const _ReaderAppearanceResult({
    required this.theme,
    required this.fontSize,
    required this.lineHeight,
  });
}
