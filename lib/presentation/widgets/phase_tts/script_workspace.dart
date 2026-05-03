import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/phase_tts/split_rules_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Left-pane script workspace. It keeps the original text and split controls;
/// the generated segment list lives in the right pane.
class PhaseScriptWorkspace extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final VoidCallback onScriptChanged;
  final void Function(SplitRule rule) onAutoSplit;

  const PhaseScriptWorkspace({
    super.key,
    required this.controller,
    required this.onScriptChanged,
    required this.onAutoSplit,
  });

  @override
  ConsumerState<PhaseScriptWorkspace> createState() =>
      _PhaseScriptWorkspaceState();
}

class _PhaseScriptWorkspaceState extends ConsumerState<PhaseScriptWorkspace> {
  String? _selectedRuleId;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(splitRulesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'SCRIPT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              rulesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (rules) => _SplitToolbar(
                  rules: rules,
                  selectedId: _selectedRuleId,
                  onSelect: (id) => setState(() => _selectedRuleId = id),
                  onRun: () {
                    final rule = _resolveRule(rules);
                    if (rule == null) return;
                    widget.onAutoSplit(rule);
                  },
                  onManage: () async {
                    final changed = await showSplitRulesDialog(context);
                    if (changed == true) {
                      ref.invalidate(splitRulesProvider);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => widget.onScriptChanged(),
              decoration: InputDecoration(
                hintText:
                    'Paste your novel text here...\n\nUse Auto Split to break it into TTS segments.',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                filled: true,
                fillColor: AppTheme.surfaceDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  SplitRule? _resolveRule(List<SplitRule> rules) {
    final enabled = rules.where((rule) => rule.enabled).toList();
    if (enabled.isEmpty) return null;
    if (_selectedRuleId == null) return enabled.first;
    return enabled.firstWhere(
      (rule) => rule.id == _selectedRuleId,
      orElse: () => enabled.first,
    );
  }
}

class _SplitToolbar extends StatelessWidget {
  final List<SplitRule> rules;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onRun;
  final VoidCallback onManage;

  const _SplitToolbar({
    required this.rules,
    required this.selectedId,
    required this.onSelect,
    required this.onRun,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = rules.where((rule) => rule.enabled).toList();
    final activeId =
        selectedId != null && enabled.any((rule) => rule.id == selectedId)
        ? selectedId
        : (enabled.isNotEmpty ? enabled.first.id : null);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeId,
              isDense: true,
              hint: const Text('No rule', style: TextStyle(fontSize: 12)),
              items: [
                for (final rule in enabled)
                  DropdownMenuItem(
                    value: rule.id,
                    child: Text(
                      rule.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onSelect(value);
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Manage rules',
          onPressed: onManage,
          icon: const Icon(Icons.tune_rounded, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: enabled.isEmpty ? null : onRun,
          icon: const Icon(Icons.splitscreen_rounded, size: 16),
          label: const Text('Auto Split'),
        ),
      ],
    );
  }
}
