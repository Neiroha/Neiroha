import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
          Expanded(child: Text(AppLocalizations.of(context).uiSplitRules)),
          IconButton(
            tooltip: AppLocalizations.of(context).uiAddRule,
            onPressed: _addRule,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 420,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : _rules.isEmpty
            ? Center(child: Text(AppLocalizations.of(context).uiNoRules))
            : ListView.separated(
                itemCount: _rules.length,
                separatorBuilder: (_, _) => SizedBox(height: 6),
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
          child: Text(AppLocalizations.of(context).uiClose),
        ),
        FilledButton(
          onPressed: _dirty
              ? () async {
                  await _save();
                  if (context.mounted) Navigator.pop(context, true);
                }
              : null,
          child: Text(AppLocalizations.of(context).uiSave),
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
    final subtitle = rule.isNewline ? 'paragraph (blank line)' : rule.pattern;
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
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
          title: Text(
            existing == null
                ? AppLocalizations.of(context).uiNewSplitRule
                : AppLocalizations.of(context).uiEditSplitRule,
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiName,
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiMode,
                  ),
                  initialValue: mode,
                  items: [
                    DropdownMenuItem(
                      value: 'regex',
                      child: Text(
                        AppLocalizations.of(context).uiSplitAtRegexMatch,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'newline',
                      child: Text(
                        AppLocalizations.of(context).uiSplitAtBlankLines,
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => mode = v);
                  },
                ),
                if (mode == 'regex') ...[
                  SizedBox(height: 12),
                  TextField(
                    controller: patternCtrl,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).uiRegexPattern,
                      helperText: r'Examples: [\.。!！?？]   /  ["”]   /  \n+',
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
              child: Text(AppLocalizations.of(context).uiCancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => error = AppLocalizations.of(context).uiNameIsRequired,
                  );
                  return;
                }
                if (mode == 'regex') {
                  final pat = patternCtrl.text;
                  if (pat.trim().isEmpty) {
                    setDialogState(
                      () => error = AppLocalizations.of(
                        context,
                      ).uiPatternIsRequired,
                    );
                    return;
                  }
                  try {
                    RegExp(pat);
                  } on FormatException catch (e) {
                    setDialogState(
                      () => error = AppLocalizations.of(
                        context,
                      ).uiInvalidRegex(e.message),
                    );
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
