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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceDim,
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
                ? 'Idle'
                : 'Generating ${generatingSegmentIds.length} segment(s)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          SizedBox(height: 18),
          _PanelTitle('OUTPUT'),
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

class _VoiceDropdown extends StatelessWidget {
  final String? value;
  final List<db.VoiceAsset> assets;
  final String label;
  final ValueChanged<String?> onChanged;

  const _VoiceDropdown({
    required this.value,
    required this.assets,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = assets.map((asset) => asset.id).toSet();
    final effectiveValue = value != null && ids.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      decoration: InputDecoration(labelText: label, isDense: true),
      isExpanded: true,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(AppLocalizations.of(context).uiUnassigned),
        ),
        for (final asset in assets)
          DropdownMenuItem(
            value: asset.id,
            child: Text(asset.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _CacheColorRow extends StatelessWidget {
  final String currentLabel;
  final String currentValue;
  final Color currentFallback;
  final ValueChanged<String> onCurrentChanged;
  final String changedLabel;
  final String changedValue;
  final Color changedFallback;
  final ValueChanged<String> onChangedChanged;

  const _CacheColorRow({
    required this.currentLabel,
    required this.currentValue,
    required this.currentFallback,
    required this.onCurrentChanged,
    required this.changedLabel,
    required this.changedValue,
    required this.changedFallback,
    required this.onChangedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _ColorChipButton(
              label: currentLabel,
              value: currentValue,
              fallback: currentFallback,
              onChanged: onCurrentChanged,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _ColorChipButton(
              label: changedLabel,
              value: changedValue,
              fallback: changedFallback,
              onChanged: onChangedChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorChipButton extends StatelessWidget {
  final String label;
  final String value;
  final Color fallback;
  final ValueChanged<String> onChanged;

  const _ColorChipButton({
    required this.label,
    required this.value,
    required this.fallback,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(value, fallback);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 38),
      ),
      onPressed: () async {
        final picked = await showDialog<String>(
          context: context,
          builder: (_) => _ColorPickerDialog(
            initialHex: _hexFromColor(color),
            fallback: fallback,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  _hexFromColor(color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final String initialHex;
  final Color fallback;

  const _ColorPickerDialog({required this.initialHex, required this.fallback});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late final TextEditingController _controller;

  static const _palette = [
    Color(0xFF2F6B54),
    Color(0xFF3E6B8F),
    Color(0xFF6A5BA8),
    Color(0xFF7A5A2A),
    Color(0xFF8C4B4B),
    Color(0xFF62656F),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialHex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _colorFromHex(_controller.text, widget.fallback);
    return AlertDialog(
      title: Text(AppLocalizations.of(context).uiCacheHighlightColor),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _palette)
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        setState(() => _controller.text = _hexFromColor(color)),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == color
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiHexColor,
              ),
              onChanged: (_) => setState(() {}),
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
            _hexFromColor(_colorFromHex(_controller.text, widget.fallback)),
          ),
          child: Text(AppLocalizations.of(context).uiApply),
        ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            valueLabel ?? value.toStringAsFixed(label == 'Font' ? 0 : 1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _CompactSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String label;

  const _PanelTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: Colors.white.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

class _ReaderColors {
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color active;

  const _ReaderColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.active,
  });
}

class _NovelDialogueRulesDialog extends ConsumerStatefulWidget {
  const _NovelDialogueRulesDialog();

  @override
  ConsumerState<_NovelDialogueRulesDialog> createState() =>
      _NovelDialogueRulesDialogState();
}

class _NovelDialogueRulesDialogState
    extends ConsumerState<_NovelDialogueRulesDialog> {
  List<NovelDialogueRule> _rules = const [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await ref.read(novelDialogueRulesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(novelDialogueRulesServiceProvider).save(_rules);
    ref.invalidate(novelDialogueRulesProvider);
    _dirty = false;
  }

  Future<void> _addRule() async {
    final rule = await _showNovelDialogueRuleEditor(context);
    if (rule == null) return;
    setState(() {
      _rules = [..._rules, rule];
      _dirty = true;
    });
  }

  Future<void> _editRule(NovelDialogueRule rule) async {
    final next = await _showNovelDialogueRuleEditor(context, existing: rule);
    if (next == null) return;
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) next else item,
      ];
      _dirty = true;
    });
  }

  void _deleteRule(NovelDialogueRule rule) {
    if (rule.builtIn) return;
    setState(() {
      _rules = _rules.where((item) => item.id != rule.id).toList();
      _dirty = true;
    });
  }

  void _toggleRule(NovelDialogueRule rule, bool enabled) {
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) item.copyWith(enabled: enabled) else item,
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(AppLocalizations.of(context).uiDialogueRules)),
          IconButton(
            tooltip: AppLocalizations.of(context).uiAddRule,
            onPressed: _loading ? null : _addRule,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 430,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : ListView.separated(
                itemCount: _rules.length,
                separatorBuilder: (_, _) => SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  return _DialogueRuleTile(
                    rule: rule,
                    onToggle: (enabled) => _toggleRule(rule, enabled),
                    onEdit: rule.builtIn ? null : () => _editRule(rule),
                    onDelete: rule.builtIn ? null : () => _deleteRule(rule),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).uiClose),
        ),
        FilledButton(
          onPressed: () async {
            if (_dirty) await _save();
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(
            _dirty
                ? AppLocalizations.of(context).novelSaveApply
                : AppLocalizations.of(context).uiApply,
          ),
        ),
      ],
    );
  }
}

class _DialogueRuleTile extends StatelessWidget {
  final NovelDialogueRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DialogueRuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Switch(value: rule.enabled, onChanged: onToggle),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (rule.builtIn) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context).uiBuiltIn,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accentColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  rule.pattern,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiEdit,
            icon: const Icon(Icons.edit_rounded, size: 16),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiDelete,
            icon: const Icon(Icons.delete_rounded, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

Future<NovelDialogueRule?> _showNovelDialogueRuleEditor(
  BuildContext context, {
  NovelDialogueRule? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final patternCtrl = TextEditingController(text: existing?.pattern ?? '');
  String? error;

  return showDialog<NovelDialogueRule>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(
            existing == null ? 'New Dialogue Rule' : 'Edit Dialogue Rule',
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiName,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: patternCtrl,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiRegexPattern,
                    helperText: r'Examples: “[\s\S]*?”   /   "[\s\S]*?"',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pattern = patternCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = 'Name is required');
                  return;
                }
                if (pattern.isEmpty) {
                  setDialogState(() => error = 'Pattern is required');
                  return;
                }
                try {
                  RegExp(pattern, multiLine: true, dotAll: true);
                } on FormatException catch (e) {
                  setDialogState(() => error = 'Invalid regex: ${e.message}');
                  return;
                }
                Navigator.pop(
                  ctx,
                  NovelDialogueRule(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    pattern: pattern,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: Text(AppLocalizations.of(context).uiSave),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    nameCtrl.dispose();
    patternCtrl.dispose();
  });
}

class _NovelTextFilterRulesDialog extends ConsumerStatefulWidget {
  const _NovelTextFilterRulesDialog();

  @override
  ConsumerState<_NovelTextFilterRulesDialog> createState() =>
      _NovelTextFilterRulesDialogState();
}

class _NovelTextFilterRulesDialogState
    extends ConsumerState<_NovelTextFilterRulesDialog> {
  List<NovelTextFilterRule> _rules = const [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await ref.read(novelTextFilterRulesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(novelTextFilterRulesServiceProvider).save(_rules);
    ref.invalidate(novelTextFilterRulesProvider);
    _dirty = false;
  }

  Future<void> _addRule() async {
    final rule = await _showNovelTextFilterRuleEditor(context);
    if (rule == null) return;
    setState(() {
      _rules = [..._rules, rule];
      _dirty = true;
    });
  }

  Future<void> _editRule(NovelTextFilterRule rule) async {
    final next = await _showNovelTextFilterRuleEditor(context, existing: rule);
    if (next == null) return;
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) next else item,
      ];
      _dirty = true;
    });
  }

  void _deleteRule(NovelTextFilterRule rule) {
    if (rule.builtIn) return;
    setState(() {
      _rules = _rules.where((item) => item.id != rule.id).toList();
      _dirty = true;
    });
  }

  void _toggleRule(NovelTextFilterRule rule, bool enabled) {
    setState(() {
      _rules = [
        for (final item in _rules)
          if (item.id == rule.id) item.copyWith(enabled: enabled) else item,
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(AppLocalizations.of(context).novelTextFilterRules),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiAddRule,
            onPressed: _loading ? null : _addRule,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 430,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : ListView.separated(
                itemCount: _rules.length,
                separatorBuilder: (_, _) => SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final rule = _rules[index];
                  return _TextFilterRuleTile(
                    rule: rule,
                    onToggle: (enabled) => _toggleRule(rule, enabled),
                    onEdit: rule.builtIn ? null : () => _editRule(rule),
                    onDelete: rule.builtIn ? null : () => _deleteRule(rule),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).uiClose),
        ),
        FilledButton(
          onPressed: () async {
            if (_dirty) await _save();
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(
            _dirty
                ? AppLocalizations.of(context).novelSaveApply
                : AppLocalizations.of(context).uiApply,
          ),
        ),
      ],
    );
  }
}

class _TextFilterRuleTile extends StatelessWidget {
  final NovelTextFilterRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TextFilterRuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Switch(value: rule.enabled, onChanged: onToggle),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (rule.builtIn) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          AppLocalizations.of(context).uiBuiltIn,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accentColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  rule.replacement.isEmpty
                      ? rule.pattern
                      : '${rule.pattern} -> ${rule.replacement}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiEdit,
            icon: const Icon(Icons.edit_rounded, size: 16),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).uiDelete,
            icon: const Icon(Icons.delete_rounded, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

Future<NovelTextFilterRule?> _showNovelTextFilterRuleEditor(
  BuildContext context, {
  NovelTextFilterRule? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final patternCtrl = TextEditingController(text: existing?.pattern ?? '');
  final replacementCtrl = TextEditingController(
    text: existing?.replacement ?? '',
  );
  String? error;

  return showDialog<NovelTextFilterRule>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(
            existing == null
                ? AppLocalizations.of(context).novelNewTextFilterRule
                : AppLocalizations.of(context).novelEditTextFilterRule,
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiName,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: patternCtrl,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiRegexPattern,
                    helperText:
                        r'Examples: [\u{1F300}-\u{1FAFF}]+   /   \(.*?\)',
                    errorText: error,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: replacementCtrl,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).novelReplacement,
                    helperText: AppLocalizations.of(
                      context,
                    ).novelReplacementHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final pattern = patternCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => error = AppLocalizations.of(context).uiNameIsRequired,
                  );
                  return;
                }
                if (pattern.isEmpty) {
                  setDialogState(
                    () => error = AppLocalizations.of(
                      context,
                    ).novelPatternRequired,
                  );
                  return;
                }
                try {
                  RegExp(pattern, multiLine: true, dotAll: true, unicode: true);
                } on FormatException catch (e) {
                  setDialogState(
                    () => error = AppLocalizations.of(
                      context,
                    ).uiInvalidRegex(e.message),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  NovelTextFilterRule(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    pattern: pattern,
                    replacement: replacementCtrl.text,
                    builtIn: existing?.builtIn ?? false,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: Text(AppLocalizations.of(context).uiSave),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    nameCtrl.dispose();
    patternCtrl.dispose();
    replacementCtrl.dispose();
  });
}
