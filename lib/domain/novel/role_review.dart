/// Persistent local review. Accepting an AI suggestion is not manual confirmation.
class RoleReviewBudget {
  const RoleReviewBudget({
    this.maxCalls = 3,
    this.maxTokens = 20000,
    this.outputTokens = 1600,
    this.inputBytes = 12000,
    this.maxReads = 6,
    this.maxProposals = 8,
  });
  final int maxCalls,
      maxTokens,
      outputTokens,
      inputBytes,
      maxReads,
      maxProposals;
  void validate() {
    if (maxCalls < 1 ||
        maxCalls > 6 ||
        maxTokens < 2000 ||
        maxTokens > 40000 ||
        outputTokens < 256 ||
        outputTokens > 2000 ||
        inputBytes < 2000 ||
        inputBytes > 16000 ||
        maxReads < 1 ||
        maxReads > 8 ||
        maxProposals < 1 ||
        maxProposals > 12) {
      throw ArgumentError('Invalid local review budget.');
    }
  }

  Map<String, Object?> toJson() => {
    'maxCalls': maxCalls,
    'maxTokens': maxTokens,
    'outputTokens': outputTokens,
    'inputBytes': inputBytes,
    'maxReads': maxReads,
    'maxProposals': maxProposals,
  };
  factory RoleReviewBudget.fromJson(Map<String, dynamic> j) => RoleReviewBudget(
    maxCalls: j['maxCalls'] as int,
    maxTokens: j['maxTokens'] as int,
    outputTokens: j['outputTokens'] as int,
    inputBytes: j['inputBytes'] as int,
    maxReads: j['maxReads'] as int,
    maxProposals: j['maxProposals'] as int,
  );
}

class RoleReviewProposal {
  const RoleReviewProposal({
    required this.key,
    required this.action,
    required this.data,
  });
  final String key, action;
  final Map<String, dynamic> data;
  String get reason => data['reason'] as String;
  List<Map<String, dynamic>> get evidence =>
      (data['evidence'] as List).cast<Map<String, dynamic>>();
  Map<String, Object?> toJson() => {'key': key, 'action': action, 'data': data};
  factory RoleReviewProposal.fromJson(Map<String, dynamic> j) =>
      RoleReviewProposal(
        key: j['key'] as String,
        action: j['action'] as String,
        data: Map<String, dynamic>.from(j['data'] as Map),
      );
}

class RoleReviewSession {
  RoleReviewSession({
    required this.id,
    required this.projectId,
    required this.chapterId,
    required this.signature,
    required this.skillDigest,
    required this.providerId,
    required this.model,
    required this.targets,
    this.budget = const RoleReviewBudget(),
    this.status = 'paused',
    this.calls = 0,
    this.chargedTokens = 0,
    this.reportedTokens = 0,
    this.reads = 0,
    this.elapsedMs = 0,
    this.error,
    this.summary = '',
    this.owner,
    this.leaseUntil = 0,
    List<String>? visibleIds,
    List<RoleReviewProposal>? proposals,
    List<Map<String, dynamic>>? journal,
    List<String>? appliedKeys,
    Map<String, List<String>>? excerpts,
  }) : visibleIds = visibleIds ?? [...targets],
       proposals = proposals ?? [],
       journal = journal ?? [],
       appliedKeys = appliedKeys ?? [],
       excerpts = excerpts ?? {};
  final String id,
      projectId,
      chapterId,
      signature,
      skillDigest,
      providerId,
      model;
  final List<String> targets;
  final RoleReviewBudget budget;
  String status, summary;
  int calls, chargedTokens, reportedTokens, reads, elapsedMs;
  String? error;
  String? owner;
  int leaseUntil;
  final List<String> visibleIds, appliedKeys;
  final List<RoleReviewProposal> proposals;
  final Map<String, List<String>> excerpts;
  final List<Map<String, dynamic>> journal;
  bool get canApply =>
      proposals.isNotEmpty &&
      ['ready', 'paused', 'budgetExhausted', 'failed'].contains(status);
  bool get canResume =>
      ['paused', 'failed', 'running'].contains(status) &&
      calls < budget.maxCalls &&
      chargedTokens < budget.maxTokens;
  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'projectId': projectId,
    'chapterId': chapterId,
    'signature': signature,
    'skillDigest': skillDigest,
    'providerId': providerId,
    'model': model,
    'targets': targets,
    'budget': budget.toJson(),
    'status': status,
    'calls': calls,
    'chargedTokens': chargedTokens,
    'reportedTokens': reportedTokens,
    'reads': reads,
    'elapsedMs': elapsedMs,
    'error': error,
    'summary': summary,
    'owner': owner,
    'leaseUntil': leaseUntil,
    'visibleIds': visibleIds,
    'excerpts': excerpts,
    'proposals': proposals.map((p) => p.toJson()).toList(),
    'journal': journal,
    'appliedKeys': appliedKeys,
  };
  factory RoleReviewSession.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unknown local review version.');
    }
    return RoleReviewSession(
      id: j['id'] as String,
      projectId: j['projectId'] as String,
      chapterId: j['chapterId'] as String,
      signature: j['signature'] as String,
      skillDigest: j['skillDigest'] as String,
      providerId: j['providerId'] as String,
      model: j['model'] as String,
      targets: (j['targets'] as List).cast<String>(),
      budget: RoleReviewBudget.fromJson(
        Map<String, dynamic>.from(j['budget'] as Map),
      ),
      status: j['status'] as String,
      calls: j['calls'] as int,
      chargedTokens: j['chargedTokens'] as int,
      reportedTokens: j['reportedTokens'] as int,
      reads: j['reads'] as int,
      elapsedMs: j['elapsedMs'] as int,
      error: j['error'] as String?,
      summary: j['summary'] as String,
      owner: j['owner'] as String?,
      leaseUntil: j['leaseUntil'] as int? ?? 0,
      visibleIds: (j['visibleIds'] as List).cast<String>(),
      excerpts: {
        for (final e in (j['excerpts'] as Map? ?? {}).entries)
          e.key as String: (e.value as List).cast<String>(),
      },
      proposals: (j['proposals'] as List)
          .map(
            (p) => RoleReviewProposal.fromJson(
              Map<String, dynamic>.from(p as Map),
            ),
          )
          .toList(),
      journal: (j['journal'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      appliedKeys: (j['appliedKeys'] as List).cast<String>(),
    );
  }
}
