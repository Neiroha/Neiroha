part of '../../screens/novel_reader_screen.dart';

// Editor for the rules that filter text before it is read.

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
