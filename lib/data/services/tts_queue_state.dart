part of 'tts_queue_service.dart';

// Per-lane rate state: requests and tokens in the last minute and today.

class _ProviderQueueState {
  final Queue<_QueuedTtsTask<dynamic>> pending =
      Queue<_QueuedTtsTask<dynamic>>();
  final Set<_QueuedTtsTask<dynamic>> activeTasks = <_QueuedTtsTask<dynamic>>{};
  final List<_UsageStamp> _minuteUsage = <_UsageStamp>[];

  int _dayRequests = 0;
  int _dayTokens = 0;
  DateTime _dayStart = _today(DateTime.now());
  Timer? timer;

  Duration waitBeforeStart(QueueLimits provider, int tokens) {
    final now = DateTime.now();
    _prune(now);
    _resetDayIfNeeded(now);

    final waits = <Duration>[];
    final rpm = _positive(provider.requestsPerMinute);
    if (rpm != null && _minuteUsage.length >= rpm) {
      waits.add(_until(_minuteUsage.first.startedAt, now));
    }

    final tpm = _positive(provider.tokensPerMinute);
    if (tpm != null && tokens > tpm) {
      if (_minuteUsage.isNotEmpty) {
        waits.add(_until(_minuteUsage.first.startedAt, now));
      }
    } else if (tpm != null) {
      final currentTokens = _minuteUsage.fold<int>(
        0,
        (sum, stamp) => sum + stamp.tokens,
      );
      var projected = currentTokens + tokens;
      for (final stamp in _minuteUsage) {
        if (projected <= tpm) break;
        projected -= stamp.tokens;
        waits.add(_until(stamp.startedAt, now));
      }
    }

    final rpd = _positive(provider.requestsPerDay);
    if (rpd != null && _dayRequests >= rpd) {
      waits.add(_untilNextDay(now));
    }

    final tpd = _positive(provider.tokensPerDay);
    if (tpd != null &&
        ((tokens > tpd && _dayTokens > 0) ||
            (tokens <= tpd && _dayTokens + tokens > tpd))) {
      waits.add(_untilNextDay(now));
    }

    return waits.fold<Duration>(
      Duration.zero,
      (maxWait, wait) => wait > maxWait ? wait : maxWait,
    );
  }

  void recordStart(int tokens) {
    final now = DateTime.now();
    _prune(now);
    _resetDayIfNeeded(now);
    _minuteUsage.add(_UsageStamp(now, tokens));
    _dayRequests++;
    _dayTokens += tokens;
  }

  void _prune(DateTime now) {
    _minuteUsage.removeWhere(
      (stamp) =>
          now.difference(stamp.startedAt) >= TtsQueueService._minuteWindow,
    );
  }

  void _resetDayIfNeeded(DateTime now) {
    final today = _today(now);
    if (today == _dayStart) return;
    _dayStart = today;
    _dayRequests = 0;
    _dayTokens = 0;
  }

  Duration _until(DateTime startedAt, DateTime now) {
    final wait = startedAt.add(TtsQueueService._minuteWindow).difference(now);
    if (wait <= Duration.zero) return const Duration(milliseconds: 1);
    return wait + const Duration(milliseconds: 10);
  }

  Duration _untilNextDay(DateTime now) {
    return _today(now).add(const Duration(days: 1)).difference(now);
  }

  static int? _positive(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static DateTime _today(DateTime now) =>
      DateTime(now.year, now.month, now.day);
}

class _UsageStamp {
  const _UsageStamp(this.startedAt, this.tokens);

  final DateTime startedAt;
  final int tokens;
}
