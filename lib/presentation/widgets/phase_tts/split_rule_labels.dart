import 'package:flutter/widgets.dart';

import 'package:neiroha/data/storage/split_rules_service.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

String localizedSplitRuleName(BuildContext context, SplitRule rule) {
  if (!rule.builtIn) return rule.name;
  final l10n = AppLocalizations.of(context);
  return switch (rule.id) {
    'builtin.newline' => l10n.splitRuleNewlineName,
    'builtin.sentence' => l10n.splitRuleSentenceName,
    'builtin.quotes' => l10n.splitRuleQuotesName,
    _ => rule.name,
  };
}

String localizedSplitRuleSummary(BuildContext context, SplitRule rule) {
  if (rule.isNewline) {
    return AppLocalizations.of(context).uiSplitAtBlankLines;
  }
  return rule.pattern;
}
