part of '../../screens/novel_reader_screen.dart';

// Small controls shared by the reader settings: voice, color, slider, switch.

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
