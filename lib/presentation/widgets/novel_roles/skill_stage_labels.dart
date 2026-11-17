import 'package:neiroha/l10n/generated/app_localizations.dart';

String roleSkillStageLabel(AppLocalizations l, String stage) => switch (stage) {
  'planner' => l.roleStagePlan,
  'executor' => l.roleStageLabel,
  'reviewer' => l.roleStageReview,
  'replanner' => l.roleStageReplan,
  'tool_reviewer' => l.roleToolReview,
  'caster' => l.roleSuggestCast,
  'director' => l.roleSuggestTone,
  _ => stage,
};
