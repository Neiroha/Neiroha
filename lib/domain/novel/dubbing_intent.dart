enum DubbingMode { automatic, storyteller, dramatized, script }

String _guidance(DubbingMode mode) => switch (mode) {
  DubbingMode.automatic => '',
  DubbingMode.storyteller =>
    'Voice embedded quotations as the outer storyteller. Keep independently speaking people distinct outside the quoted story.',
  DubbingMode.dramatized =>
    'Give explicitly attributed direct quotations their own character voices, including nested quotes. Return to the outer storyteller after each quotation.',
  DubbingMode.script =>
    'Use explicit speaker headers for dialogue. Treat stage directions as narration and distinguish chat senders from the people they address.',
};

String dubbingIntent(DubbingMode mode, String notes) =>
    [_guidance(mode), notes.trim()].where((s) => s.isNotEmpty).join('\n\n');

(DubbingMode, String) readDubbingIntent(String feedback) {
  for (final mode in DubbingMode.values.skip(1)) {
    final guidance = _guidance(mode);
    if (feedback == guidance) return (mode, '');
    if (feedback.startsWith('$guidance\n\n')) {
      return (mode, feedback.substring(guidance.length + 2));
    }
  }
  return (DubbingMode.automatic, feedback);
}

class RoleAnalysisProgress {
  const RoleAnalysisProgress({
    required this.stage,
    required this.processed,
    required this.total,
    required this.calls,
  });
  final String stage;
  final int processed, total, calls;
}
