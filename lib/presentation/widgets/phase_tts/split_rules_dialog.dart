import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Modal where the user manages global split rules: rename, edit pattern,
/// add custom rules, delete user-added rules. Built-in rules can only be
/// toggled on/off. Returns `true` if anything was edited so the caller can
/// invalidate downstream providers.
Future<bool?> showSplitRulesDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const _SplitRulesDialog(),
  );
}

class _SplitRulesDialog extends ConsumerStatefulWidget {
  const _SplitRulesDialog();

  @override
  ConsumerState<_SplitRulesDialog> createState() => _SplitRulesDialogState();
}

class _SplitRulesDialogState extends ConsumerState<_SplitRulesDialog> {
  List<SplitRule> _rules = const [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ref.read(splitRulesServiceProvider).load();
    if (!mounted) return;
    setState(() {
      _rules = loaded;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await ref.read(splitRulesServiceProvider).save(_rules);
    ref.invalidate(splitRulesProvider);
    _dirty = false;
  }

  void _addRule() async {
    final result = await showSplitRuleEditor(context);
    if (result == null) return;
    setState(() {
      _rules = [..._rules, result];
      _dirty = true;
    });
  }

  void _editRule(SplitRule rule) async {
    final result = await showSplitRuleEditor(context, existing: rule);
    if (result == null) return;
    setState(() {
      _rules = [
        for (final r in _rules)
          if (r.id == rule.id) result else r,
      ];
      _dirty = true;
    });
  }

  void _deleteRule(SplitRule rule) {
    if (rule.builtIn) return;
    setState(() {
      _rules = _rules.where((r) => r.id != rule.id).toList();
      _dirty = true;
    });
  }

  void _toggle(SplitRule rule, bool enabled) {
    setState(() {
      _rules = [
        for (final r in _rules)
          if (r.id == rule.id) r.copyWith(enabled: enabled) else r,
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Split Rules')),
          IconButton(
            tooltip: 'Add rule',
            onPressed: _addRule,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rules.isEmpty
                ? const Center(child: Text('No rules'))
                : ListView.separated(
                    itemCount: _rules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _RuleTile(
                      rule: _rules[i],
                      onEdit: () => _editRule(_rules[i]),
                      onDelete: () => _deleteRule(_rules[i]),
                      onToggle: (v) => _toggle(_rules[i], v),
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _dirty),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _dirty
              ? () async {
                  await _save();
                  if (context.mounted) Navigator.pop(context, true);
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  final SplitRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        rule.isNewline ? 'paragraph (blank line)' : rule.pattern;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDim,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Switch(
            value: rule.enabled,
            onChanged: onToggle,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rule.builtIn) ...[
                      const SizedBox(width: 6),
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
                          'built-in',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.accentColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: rule.isNewline ? null : 'monospace',
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!rule.builtIn) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded, size: 16),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_rounded, size: 16),
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// Add/edit form for a single rule. Validates the regex before letting the
/// user save so they don't end up with a rule that always falls back to
/// "no split".
Future<SplitRule?> showSplitRuleEditor(
  BuildContext context, {
  SplitRule? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final patternCtrl = TextEditingController(text: existing?.pattern ?? '');
  String mode = existing?.mode ?? 'regex';
  String? error;

  return showDialog<SplitRule>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Text(existing == null ? 'New Split Rule' : 'Edit Split Rule'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Mode'),
                  initialValue: mode,
                  items: const [
                    DropdownMenuItem(
                      value: 'regex',
                      child: Text('Split at regex match'),
                    ),
                    DropdownMenuItem(
                      value: 'newline',
                      child: Text('Split at blank lines'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => mode = v);
                  },
                ),
                if (mode == 'regex') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: patternCtrl,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'Regex pattern',
                      helperText:
                          r'Examples: [\.。!！?？]   /  ["”]   /  \n+',
                      errorText: error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = 'Name is required');
                  return;
                }
                if (mode == 'regex') {
                  final pat = patternCtrl.text;
                  if (pat.trim().isEmpty) {
                    setDialogState(() => error = 'Pattern is required');
                    return;
                  }
                  try {
                    RegExp(pat);
                  } on FormatException catch (e) {
                    setDialogState(() => error = 'Invalid regex: ${e.message}');
                    return;
                  }
                }
                Navigator.pop(
                  ctx,
                  SplitRule(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    mode: mode,
                    pattern: mode == 'regex' ? patternCtrl.text : '',
                    builtIn: false,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: const Text('Save'),
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
