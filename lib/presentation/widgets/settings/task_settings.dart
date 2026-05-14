import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';

// ───────────────────────────── Task monitor card ────────────────────────────

class TaskMonitorSettingsCard extends ConsumerWidget {
  const TaskMonitorSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref
        .watch(ttsQueueSnapshotProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => ref.read(ttsQueueServiceProvider).snapshot,
        );
    final recent = snapshot.recent.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsRow(
              icon: Icons.task_alt_rounded,
              title: 'Current TTS Tasks',
              subtitle: snapshot.hasUnfinished
                  ? '${snapshot.runningCount} running, ${snapshot.queuedCount} waiting'
                  : 'No unfinished TTS tasks right now.',
              trailing: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TaskCountChip(
                    label: 'Running',
                    count: snapshot.runningCount,
                    color: Colors.lightGreenAccent,
                  ),
                  _TaskCountChip(
                    label: 'Queued',
                    count: snapshot.queuedCount,
                    color: AppTheme.accentColor,
                  ),
                ],
              ),
            ),
            const Divider(),
            if (!snapshot.hasUnfinished)
              const _EmptyTaskState()
            else ...[
              _TaskSection(title: 'Running', tasks: snapshot.running),
              _TaskSection(title: 'Waiting', tasks: snapshot.queued),
            ],
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 14),
              _TaskSection(title: 'Recent', tasks: recent, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  const _EmptyTaskState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 32,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 8),
          Text(
            'TTS queue is idle',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
          ),
        ],
      ),
    );
  }
}

class _TaskCountChip extends StatelessWidget {
  const _TaskCountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.tasks,
    this.compact = false,
  });

  final String title;
  final List<TtsQueueTaskSnapshot> tasks;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final task in tasks) _TaskRow(task: task, compact: compact),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.compact});

  final TtsQueueTaskSnapshot task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _taskStatusColor(task.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBright,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(_taskStatusIcon(task.status), size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.label,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _TaskMetaChip(
                      icon: Icons.layers_rounded,
                      label: task.source,
                    ),
                    _TaskMetaChip(
                      icon: Icons.dns_rounded,
                      label: task.providerName,
                    ),
                    _TaskMetaChip(
                      icon: Icons.schedule_rounded,
                      label: _taskTimeLabel(task),
                    ),
                    _TaskMetaChip(
                      icon: Icons.data_usage_rounded,
                      label: '${task.estimatedTokens} tok',
                    ),
                  ],
                ),
                if (task.errorMessage != null &&
                    task.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.errorMessage!,
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
          const SizedBox(width: 8),
          _TaskStatusPill(status: task.status),
        ],
      ),
    );
  }
}

class _TaskMetaChip extends StatelessWidget {
  const _TaskMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.45)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.status});

  final TtsQueueTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _taskStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        _taskStatusLabel(status),
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _taskStatusColor(TtsQueueTaskStatus status) {
  return switch (status) {
    TtsQueueTaskStatus.queued => AppTheme.accentColor,
    TtsQueueTaskStatus.running => Colors.lightGreenAccent,
    TtsQueueTaskStatus.completed => Colors.greenAccent,
    TtsQueueTaskStatus.failed => Colors.redAccent,
  };
}

IconData _taskStatusIcon(TtsQueueTaskStatus status) {
  return switch (status) {
    TtsQueueTaskStatus.queued => Icons.schedule_rounded,
    TtsQueueTaskStatus.running => Icons.sync_rounded,
    TtsQueueTaskStatus.completed => Icons.check_circle_rounded,
    TtsQueueTaskStatus.failed => Icons.error_rounded,
  };
}

String _taskStatusLabel(TtsQueueTaskStatus status) {
  return switch (status) {
    TtsQueueTaskStatus.queued => 'Queued',
    TtsQueueTaskStatus.running => 'Running',
    TtsQueueTaskStatus.completed => 'Done',
    TtsQueueTaskStatus.failed => 'Failed',
  };
}

String _taskTimeLabel(TtsQueueTaskSnapshot task) {
  final time = switch (task.status) {
    TtsQueueTaskStatus.running => task.startedAt ?? task.queuedAt,
    TtsQueueTaskStatus.completed ||
    TtsQueueTaskStatus.failed => task.completedAt ?? task.queuedAt,
    TtsQueueTaskStatus.queued => task.queuedAt,
  };
  return _formatClock(time);
}

String _formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
