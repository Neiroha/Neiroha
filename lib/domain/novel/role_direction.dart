enum RoleDirectionTask { casting, tone }

class RoleDirectionSuggestion {
  const RoleDirectionSuggestion({
    required this.id,
    required this.value,
    required this.reason,
  });

  /// Character ID for casting, segment ID for tone. Never a replacement text.
  final String id;
  final String value;
  final String reason;
}

class RoleDirectionProposal {
  const RoleDirectionProposal({
    required this.projectId,
    required this.chapterId,
    required this.task,
    required this.signature,
    required this.suggestions,
  });
  final String projectId;
  final String chapterId;
  final RoleDirectionTask task;
  final String signature;
  final List<RoleDirectionSuggestion> suggestions;
}
