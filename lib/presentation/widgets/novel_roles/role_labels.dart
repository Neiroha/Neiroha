import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

String roleKindLabel(AppLocalizations l, NovelSegmentKind kind) =>
    switch (kind) {
      NovelSegmentKind.narrator => l.roleNarrator,
      NovelSegmentKind.dialogue => l.roleDialogue,
      NovelSegmentKind.thought => l.roleThought,
      NovelSegmentKind.system => l.roleSystem,
    };

String roleReviewLabel(AppLocalizations l, NovelReviewState state) =>
    switch (state) {
      NovelReviewState.pending => l.rolePending,
      NovelReviewState.inferred => l.roleInferred,
      NovelReviewState.conflict => l.roleConflict,
      NovelReviewState.confirmed => l.roleConfirmed,
    };

String roleAnalysisStageLabel(AppLocalizations l, String stage) =>
    switch (stage) {
      'planCast' => l.roleStagePlan,
      'rosterReview' => l.roleStageRoster,
      'labelChunk' => l.roleStageLabel,
      'validate' => l.roleStageValidate,
      'review' => l.roleStageReview,
      'replanCast' => l.roleStageReplan,
      'paused' => l.roleStagePaused,
      'completed' => l.roleStageCompleted,
      'failed' => l.roleStageFailed,
      _ => l.roleStagePaused,
    };
