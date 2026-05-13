import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/data/storage/export_prefs.dart';
import 'package:neiroha/data/storage/ffmpeg_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/data/storage/storage_service.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/server/api_server.dart';

const double _settingsWideBreakpoint = 840;
const double _settingsInitialRailFraction = 0.22;
const double _settingsRailMinWidth = 220;
const double _settingsContentMaxWidth = 920;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSection = ref.watch(settingsSectionProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _settingsWideBreakpoint;
        if (isWide) {
          return HorizontalResizableSplitPane(
            initialLeftFraction: _settingsInitialRailFraction,
            minPaneWidth: _settingsRailMinWidth,
            left: _SettingsSectionRail(
              selected: selectedSection,
              onSelected: (section) =>
                  ref.read(settingsSectionProvider.notifier).state = section,
            ),
            right: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0F0F14)),
              child: _SettingsSectionContent(section: selectedSection),
            ),
          );
        }

        return Column(
          children: [
            _SettingsCompactPicker(
              selected: selectedSection,
              onSelected: (section) =>
                  ref.read(settingsSectionProvider.notifier).state = section,
            ),
            const Divider(height: 1),
            Expanded(child: _SettingsSectionContent(section: selectedSection)),
          ],
        );
      },
    );
  }
}

class _SettingsSectionRail extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  const _SettingsSectionRail({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12121A),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: SettingsSection.values.length,
              itemBuilder: (context, index) {
                final section = SettingsSection.values[index];
                return _SettingsSectionTile(
                  section: section,
                  selected: section == selected,
                  onTap: () => onSelected(section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTile extends StatefulWidget {
  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsSectionTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SettingsSectionTile> createState() => _SettingsSectionTileState();
}

class _SettingsSectionTileState extends State<_SettingsSectionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected
        ? Colors.white.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: _hovering ? 0.82 : 0.68);
    final iconColor = selected
        ? AppTheme.accentColor
        : Colors.white.withValues(alpha: _hovering ? 0.76 : 0.58);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 58,
          color: _hovering
              ? Colors.white.withValues(alpha: 0.025)
              : Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: 3,
                height: selected ? 30 : 0,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentColor : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Icon(widget.section.icon, size: 22, color: iconColor),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  widget.section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCompactPicker extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  const _SettingsCompactPicker({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceDim,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final section in SettingsSection.values) ...[
                  ChoiceChip(
                    selected: selected == section,
                    avatar: Icon(section.icon, size: 16),
                    label: Text(section.label),
                    onSelected: (_) => onSelected(section),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionContent extends ConsumerWidget {
  final SettingsSection section;

  const _SettingsSectionContent({required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = switch (section) {
      SettingsSection.general => const <Widget>[
        _StartupCard(),
        SizedBox(height: 12),
        _TaskBehaviorCard(),
      ],
      SettingsSection.tasks => const <Widget>[_TaskMonitorCard()],
      SettingsSection.api => const <Widget>[_ApiServerCard()],
      SettingsSection.storage => <Widget>[
        _StorageCard(startup: ref.watch(storageStartupProvider)),
      ],
      SettingsSection.media => const <Widget>[
        _FfmpegCard(),
        SizedBox(height: 12),
        _ExportPrefsCard(),
      ],
      SettingsSection.about => const <Widget>[_AboutCard()],
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _settingsContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          children: [
            _SettingsPageHeader(section: section),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsPageHeader extends StatelessWidget {
  final SettingsSection section;

  const _SettingsPageHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          section.label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          section.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _StartupCard extends ConsumerStatefulWidget {
  const _StartupCard();

  @override
  ConsumerState<_StartupCard> createState() => _StartupCardState();
}

class _StartupCardState extends ConsumerState<_StartupCard> {
  NavTab _startupTab = NavTab.voiceBank;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppNavigationSettings.startupTabKey);
    if (!mounted) return;
    setState(() {
      _startupTab = NavTab.fromName(stored) ?? NavTab.voiceBank;
      _loaded = true;
    });
  }

  Future<void> _setStartupTab(NavTab tab) async {
    setState(() => _startupTab = tab);
    await ref
        .read(databaseProvider)
        .setSetting(AppNavigationSettings.startupTabKey, tab.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Startup screen set to ${tab.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _SettingsRow(
          icon: Icons.home_work_rounded,
          title: 'Startup Screen',
          subtitle:
              'Choose which workspace opens when Neiroha starts. This applies on the next launch.',
          trailing: DropdownButton<NavTab>(
            value: _startupTab,
            underline: const SizedBox.shrink(),
            items: [
              for (final tab in NavTab.values)
                DropdownMenuItem(value: tab, child: Text(tab.label)),
            ],
            onChanged: !_loaded
                ? null
                : (tab) {
                    if (tab != null && tab != _startupTab) {
                      _setStartupTab(tab);
                    }
                  },
          ),
        ),
      ),
    );
  }
}

class _TaskBehaviorCard extends ConsumerStatefulWidget {
  const _TaskBehaviorCard();

  @override
  ConsumerState<_TaskBehaviorCard> createState() => _TaskBehaviorCardState();
}

class _TaskBehaviorCardState extends ConsumerState<_TaskBehaviorCard> {
  bool _loaded = false;
  bool _continueAcrossScreens =
      AppBehaviorSettings.defaultContinueTtsAcrossScreens;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppBehaviorSettings.continueTtsAcrossScreensKey);
    final enabled = AppBehaviorSettings.parseBool(
      stored,
      defaultValue: AppBehaviorSettings.defaultContinueTtsAcrossScreens,
    );
    if (!mounted) return;
    ref.read(continueTtsAcrossScreensProvider.notifier).state = enabled;
    setState(() {
      _continueAcrossScreens = enabled;
      _loaded = true;
    });
  }

  Future<void> _setContinueAcrossScreens(bool enabled) async {
    setState(() => _continueAcrossScreens = enabled);
    ref.read(continueTtsAcrossScreensProvider.notifier).state = enabled;
    await ref
        .read(databaseProvider)
        .setSetting(
          AppBehaviorSettings.continueTtsAcrossScreensKey,
          enabled ? 'true' : '',
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'TTS will continue when switching screens.'
              : 'Novel playback will stop when leaving the reader.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _SettingsRow(
          icon: Icons.swap_horiz_rounded,
          title: 'Keep TTS Running Across Screens',
          subtitle:
              'Useful for reading with Novel Reader while checking task progress or settings.',
          trailing: Switch(
            value: _continueAcrossScreens,
            onChanged: _loaded ? _setContinueAcrossScreens : null,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Task monitor card ────────────────────────────

class _TaskMonitorCard extends ConsumerWidget {
  const _TaskMonitorCard();

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
            _SettingsRow(
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: _SettingsRow(
          icon: Icons.info_outline_rounded,
          title: 'Neiroha',
          subtitle: 'v0.1.0 - AI Audio Middleware & Dubbing Workstation',
        ),
      ),
    );
  }
}

// ───────────────────────────── API server card ─────────────────────────────

class _ApiServerCard extends ConsumerStatefulWidget {
  const _ApiServerCard();

  @override
  ConsumerState<_ApiServerCard> createState() => _ApiServerCardState();
}

class _ApiServerCardState extends ConsumerState<_ApiServerCard> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _corsCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _hydrated = false;
  bool _showKey = false;
  bool _apiLogEnabled = false;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _keyCtrl.dispose();
    _corsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final cfg = await ApiServerConfig.load(ref.read(databaseProvider));
    if (!mounted) return;
    setState(() {
      _hostCtrl.text = cfg.bindHost;
      _portCtrl.text = '${cfg.port}';
      _keyCtrl.text = cfg.apiKey ?? '';
      _corsCtrl.text = cfg.corsOrigins.join(', ');
      _rateCtrl.text = '${cfg.rateLimitPerMin}';
      _apiLogEnabled = cfg.apiLogEnabled;
      _hydrated = true;
    });
  }

  ApiServerConfig _readConfig() {
    return ApiServerConfig(
      bindHost: _hostCtrl.text.trim().isEmpty
          ? '127.0.0.1'
          : _hostCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? 8976,
      apiKey: _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
      corsOrigins: _corsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      rateLimitPerMin: int.tryParse(_rateCtrl.text.trim()) ?? 60,
      apiLogEnabled: _apiLogEnabled,
    );
  }

  Future<void> _apply() async {
    final cfg = _readConfig();
    final db = ref.read(databaseProvider);
    final server = ref.read(apiServerProvider);
    await ApiServerConfig.save(db, cfg);
    if (server.isRunning) {
      await server.restart(config: cfg);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API config saved.')));
  }

  Future<void> _setApiLogEnabled(bool enabled) async {
    setState(() => _apiLogEnabled = enabled);
    await ref.read(apiServerProvider).setApiLogEnabled(enabled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled ? 'API log output enabled.' : 'API log output disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(serverRunningProvider);
    final server = ref.read(apiServerProvider);
    final apiLogs = ref
        .watch(apiServerLogsProvider)
        .maybeWhen(data: (logs) => logs, orElse: () => server.logs);

    if (!_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }

    final isPublicBind = _hostCtrl.text.trim() == '0.0.0.0';
    final hasNoKey = _keyCtrl.text.trim().isEmpty;
    final exposedWithoutAuth = isPublicBind && hasNoKey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsRow(
              icon: Icons.power_settings_new_rounded,
              title: 'API Server',
              subtitle: running
                  ? 'Running on ${server.bindHost}:${server.port}'
                  : 'Stopped',
              trailing: Switch(
                value: running,
                onChanged: (value) async {
                  if (value) {
                    await server.start();
                  } else {
                    await server.stop();
                  }
                  ref.read(serverRunningProvider.notifier).state = value;
                },
              ),
            ),
            const Divider(),
            if (exposedWithoutAuth)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bound to 0.0.0.0 with no API key — anyone on the LAN '
                        'can call your providers. Set an API key or rebind to '
                        '127.0.0.1.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final hostField = TextField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bind host',
                    hintText: '127.0.0.1',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                );
                final portField = TextField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                );

                if (compact) {
                  return Column(
                    children: [
                      hostField,
                      const SizedBox(height: 12),
                      portField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: hostField),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: portField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'API key (optional)',
                hintText: 'Bearer token / X-API-Key',
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showKey ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _corsCtrl,
              decoration: const InputDecoration(
                labelText: 'CORS origin allowlist (CSV, empty = deny all)',
                hintText: 'https://example.com, http://localhost:3000',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final rateField = TextField(
                  controller: _rateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rate limit (req/min/IP, 0 = off)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                );
                final saveButton = FilledButton.icon(
                  onPressed: _hydrated ? _apply : null,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(running ? 'Save & restart' : 'Save'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rateField,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: saveButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 200, child: rateField),
                    const Spacer(),
                    saveButton,
                  ],
                );
              },
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.receipt_long_rounded,
              title: 'API Log Output',
              subtitle:
                  'Record external API request metadata in this panel. Request bodies and auth headers are not stored.',
              trailing: Switch(
                value: _apiLogEnabled,
                onChanged: _hydrated ? _setApiLogEnabled : null,
              ),
            ),
            if (_apiLogEnabled) ...[
              const SizedBox(height: 8),
              _ApiLogPanel(
                logs: apiLogs,
                onClear: () => ref.read(apiServerProvider).clearLogs(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
                  '${logs.length} request(s)',
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
                  label: const Text('Clear'),
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
                      'No API requests logged yet.',
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
          const SizedBox(width: 10),
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
                const SizedBox(height: 3),
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
                  const SizedBox(height: 3),
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

// ───────────────────────────── Storage card ─────────────────────────────

class _StorageCard extends ConsumerWidget {
  const _StorageCard({required this.startup});

  final AsyncValue<StorageScanReport> startup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = PathService.instance;
    final dataRoot = paths.dataRoot.path;
    final voiceAssetRoot = paths.voiceAssetRoot.path;
    final isDefault =
        paths.voiceAssetRoot.path == paths.defaultVoiceAssetRoot.path;
    final missing = startup.maybeWhen(data: (r) => r.missing, orElse: () => 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettingsRow(
              icon: Icons.storage_rounded,
              title: 'Data Directory',
              subtitle:
                  '$dataRoot\n'
                  '${paths.isPortable ? 'Portable (next to executable)' : 'App-support fallback (install dir is read-only)'}',
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy path',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: dataRoot)),
              ),
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.folder_open_rounded,
              title: 'Voice Asset Directory',
              subtitle:
                  '$voiceAssetRoot\n'
                  '${isDefault ? 'Default location' : 'Custom location'}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDefault)
                    TextButton(
                      onPressed: () => _resetRoot(context, ref),
                      child: const Text('Reset'),
                    ),
                  TextButton(
                    onPressed: () => _pickRoot(context, ref),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const Divider(),
            _SettingsRow(
              icon: missing > 0
                  ? Icons.warning_amber_rounded
                  : Icons.sync_rounded,
              title: 'Sync with Disk',
              subtitle: startup.when(
                data: (r) => missing > 0
                    ? '$missing archived file(s) are missing on disk — rows flagged, not deleted.'
                    : 'All ${r.checked} archived file(s) are present.',
                loading: () => 'Scanning…',
                error: (e, _) => 'Scan failed: $e',
              ),
              trailing: startup.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => _manualSync(context, ref),
                      child: const Text('Scan Now'),
                    ),
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.delete_forever_rounded,
              title: 'Clear All Archived Audio',
              subtitle:
                  'Deletes every generated take + imported reference audio. '
                  'Projects, characters, banks are preserved.',
              trailing: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () => _clearAll(context, ref),
                child: const Text('Clear…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRoot(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose voice asset directory',
    );
    if (picked == null || picked.isEmpty) return;
    final storage = ref.read(storageServiceProvider);
    try {
      await storage.setVoiceAssetRoot(picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not use that folder: $e')),
        );
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice asset directory set to $picked')),
      );
    }
  }

  Future<void> _resetRoot(BuildContext context, WidgetRef ref) async {
    await ref.read(storageServiceProvider).setVoiceAssetRoot(null);
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice asset directory reset to default')),
      );
    }
  }

  Future<void> _manualSync(BuildContext context, WidgetRef ref) async {
    ref.invalidate(storageStartupProvider);
    final report = await ref.read(storageStartupProvider.future);
    if (!context.mounted) return;
    final msg = report.missing == 0
        ? 'Scan complete — all ${report.checked} file(s) present.'
        : 'Scan complete — ${report.missing} missing of ${report.checked}.${report.recovered > 0 ? ' ${report.recovered} recovered.' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final usage = await storage.measureVoiceAssetRoot();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ClearAudioDialog(usage: usage),
    );
    if (confirmed != true) return;
    try {
      await storage.clearAllAudioArchives();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Clear failed: $e')));
      }
      return;
    }
    ref.invalidate(storageStartupProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Archived audio cleared.')));
    }
  }
}

// ───────────────────────────── FFmpeg card ─────────────────────────────

class _FfmpegCard extends ConsumerStatefulWidget {
  const _FfmpegCard();

  @override
  ConsumerState<_FfmpegCard> createState() => _FfmpegCardState();
}

class _FfmpegCardState extends ConsumerState<_FfmpegCard> {
  final _pathCtrl = TextEditingController();
  String? _loadedOverride;
  bool _hydrated = false;

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate(FFmpegService svc) async {
    final stored = await svc.getOverride();
    if (!mounted) return;
    setState(() {
      _loadedOverride = stored;
      _pathCtrl.text = stored ?? '';
      _hydrated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(ffmpegServiceProvider);
    final availability = ref.watch(ffmpegAvailabilityProvider);

    if (!_hydrated) {
      // Lazy one-shot load of the persisted override.
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate(svc));
    }

    final isAvailable = availability.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final loading = availability.isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettingsRow(
              icon: isAvailable
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              title: 'FFmpeg',
              subtitle: loading
                  ? 'Probing…'
                  : (isAvailable
                        ? 'Detected. Used for waveform extraction and imported-media analysis.'
                        : 'Not found. Install ffmpeg (or set a path below) — the app works without it, but waveforms and media probing will be skipped.'),
              trailing: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () {
                        ref.read(ffmpegServiceProvider).invalidate();
                        ref.invalidate(ffmpegAvailabilityProvider);
                      },
                      child: const Text('Re-check'),
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsRow(
                    icon: Icons.terminal_rounded,
                    title: 'Executable Path',
                    subtitle:
                        _loadedOverride == null || _loadedOverride!.isEmpty
                        ? 'Auto-detect from PATH'
                        : 'Using override',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(onPressed: _save, child: const Text('Save')),
                        if (_loadedOverride != null &&
                            _loadedOverride!.isNotEmpty)
                          TextButton(
                            onPressed: _clear,
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText:
                          'Leave blank to auto-detect (e.g. C:\\ffmpeg\\bin\\ffmpeg.exe)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        tooltip: 'Browse…',
                        onPressed: _browse,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _browse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['exe', ''],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => _pathCtrl.text = path);
  }

  Future<void> _save() async {
    final path = _pathCtrl.text.trim();
    await ref
        .read(ffmpegServiceProvider)
        .setOverride(path.isEmpty ? null : path);
    ref.invalidate(ffmpegAvailabilityProvider);
    setState(() => _loadedOverride = path.isEmpty ? null : path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path.isEmpty
              ? 'FFmpeg path cleared — will auto-detect from PATH.'
              : 'FFmpeg path saved.',
        ),
      ),
    );
  }

  Future<void> _clear() async {
    await ref.read(ffmpegServiceProvider).setOverride(null);
    ref.invalidate(ffmpegAvailabilityProvider);
    setState(() {
      _loadedOverride = null;
      _pathCtrl.clear();
    });
  }
}

// ─────────────────── Clear-all double confirmation dialog ──────────────────

class _ClearAudioDialog extends StatefulWidget {
  const _ClearAudioDialog({required this.usage});

  final StorageUsage usage;

  @override
  State<_ClearAudioDialog> createState() => _ClearAudioDialogState();
}

class _ClearAudioDialogState extends State<_ClearAudioDialog> {
  final _confirmCtrl = TextEditingController();
  bool _acknowledged = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Case-sensitive: label reads "Type CLEAR" and the whole point of the
    // ceremony is to stop autopilot confirmations.
    final canConfirm = _acknowledged && _confirmCtrl.text.trim() == 'CLEAR';
    return AlertDialog(
      title: const Text('Clear all archived audio?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will delete ${widget.usage.fileCount} file(s) '
            '(${widget.usage.prettyBytes}) from disk and wipe:\n'
            ' • Quick TTS history\n'
            ' • Generated takes on Phase/Dialog project lines\n'
            ' • Voice asset library (reference audio)\n'
            ' • Timeline clips\n\n'
            'Your projects, characters, providers, and scripts are preserved.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _acknowledged,
                onChanged: (v) => setState(() => _acknowledged = v ?? false),
              ),
              const Expanded(
                child: Text('I understand this cannot be undone.'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(
              labelText: "Type CLEAR to confirm",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          child: const Text('Clear Audio'),
        ),
      ],
    );
  }
}

// ─────────────────────────── Shared widgets ───────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: AppTheme.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (trailing == null) return text;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              const SizedBox(width: 12),
              trailing,
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────── Export Prefs card ──────────────────────────

/// Defaults used by the Video Dub editor's Export Audio / Export Video
/// buttons. Stored in `AppSettings`; loaded once on first build then
/// persisted on every dropdown change.
class _ExportPrefsCard extends ConsumerStatefulWidget {
  const _ExportPrefsCard();

  @override
  ConsumerState<_ExportPrefsCard> createState() => _ExportPrefsCardState();
}

class _ExportPrefsCardState extends ConsumerState<_ExportPrefsCard> {
  ExportPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    // Defer the async load so initState stays sync — the card will
    // briefly render in a "loading" state until _prefs is set.
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = await ref.read(exportPrefsServiceProvider).load();
    if (!mounted) return;
    setState(() => _prefs = prefs);
  }

  Future<void> _setAudioFormat(String v) async {
    await ref.read(exportPrefsServiceProvider).setAudioFormat(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(audioFormat: v));
  }

  Future<void> _setVideoCodec(String v) async {
    await ref.read(exportPrefsServiceProvider).setVideoCodec(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(videoCodec: v));
  }

  Future<void> _setVideoAudioCodec(String v) async {
    await ref.read(exportPrefsServiceProvider).setVideoAudioCodec(v);
    if (!mounted) return;
    setState(() => _prefs = _prefs!.copyWith(videoAudioCodec: v));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: prefs == null
            ? const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : Column(
                children: [
                  _SettingsRow(
                    icon: Icons.tune_rounded,
                    title: 'Export Defaults',
                    subtitle:
                        'Used by the Video Dub editor\'s Export Audio / Export Video buttons.',
                    trailing: const SizedBox.shrink(),
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.audiotrack_rounded,
                    title: 'Audio format',
                    subtitle:
                        'Container + codec for "Export Audio". WAV/FLAC keep full quality; MP3 is smaller.',
                    value: prefs.audioFormat,
                    options: ExportPrefs.audioFormats,
                    onChanged: _setAudioFormat,
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.movie_filter_rounded,
                    title: 'Video codec',
                    subtitle:
                        '"copy" reuses the source stream (fast, lossless). h264 / h265 / av1 force a transcode (slower, ffmpeg build must support the chosen encoder).',
                    value: prefs.videoCodec,
                    options: ExportPrefs.videoCodecs,
                    onChanged: _setVideoCodec,
                  ),
                  const Divider(),
                  _PrefRow(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Video audio codec',
                    subtitle:
                        'Audio codec for the muxed MP4. AAC is the broadest-compatible default.',
                    value: prefs.videoAudioCodec,
                    options: ExportPrefs.videoAudioCodecs,
                    onChanged: _setVideoAudioCodec,
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o, child: Text(o.toUpperCase())),
        ],
        onChanged: (v) {
          if (v != null && v != value) onChanged(v);
        },
      ),
    );
  }
}
