import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/phase_tts/split_rule_labels.dart';
import 'package:neiroha/presentation/widgets/phase_tts/split_rules_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          // Wrap instead of Row so the split toolbar drops under the title
          // on narrow panes rather than overflowing.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).uiSCRIPT,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) => Text(
                      AppLocalizations.of(
                        context,
                      ).phaseCharCount(value.text.characters.length),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 14, height: 1.6),
              onChanged: (_) => widget.onScriptChanged(),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(
                  context,
                ).uiPasteYourNovelTextHereUseAutoSplitToBreakItInto,
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
              hint: Text(
                AppLocalizations.of(context).uiNoRule,
                style: TextStyle(fontSize: 12),
              ),
              items: [
                for (final rule in enabled)
                  DropdownMenuItem(
                    value: rule.id,
                    child: Text(
                      localizedSplitRuleName(context, rule),
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
          tooltip: AppLocalizations.of(context).uiManageRules,
          onPressed: onManage,
          icon: const Icon(Icons.tune_rounded, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        ),
        SizedBox(width: 4),
        FilledButton.tonalIcon(
          onPressed: enabled.isEmpty ? null : onRun,
          icon: const Icon(Icons.splitscreen_rounded, size: 16),
          label: Text(AppLocalizations.of(context).uiAutoSplit),
        ),
      ],
    );
  }
}
