part of 'api_settings.dart';

// The API request log shown under the server settings.

class _ApiLogPanel extends StatelessWidget {
  const _ApiLogPanel({required this.logs, required this.onClear});

  final List<ApiLogEntry> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context).uiRequestS(logs.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: logs.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(AppLocalizations.of(context).uiClear),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).uiNoAPIRequestsLoggedYet,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, index) =>
                        _ApiLogRow(entry: logs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ApiLogRow extends StatelessWidget {
  const _ApiLogRow({required this.entry});

  final ApiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ok = entry.statusCode < 400;
    final color = ok ? Colors.greenAccent : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${entry.statusCode}',
              style: TextStyle(
                color: color.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.method} ${entry.path}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${_formatClock(entry.startedAt)}  ${entry.remoteAddress}  ${entry.durationMs} ms',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                ),
                if (entry.errorMessage != null) ...[
                  SizedBox(height: 3),
                  Text(
                    entry.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
