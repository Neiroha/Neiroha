part of '../../screens/novel_reader_screen.dart';

// Editor for the rules that mark dialogue in chapter text.

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
        color: context.colors.panel,
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
                    color: context.fg.withValues(alpha: 0.5),
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
