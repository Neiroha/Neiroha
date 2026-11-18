import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/domain/capabilities/task_profile.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'package:neiroha/presentation/widgets/model_capability_picker.dart';

class TaskProfilesDialog extends ConsumerStatefulWidget {
  const TaskProfilesDialog({
    super.key,
    required this.projectId,
    this.beforeChange,
  });
  final String projectId;
  final VoidCallback? beforeChange;
  @override
  ConsumerState<TaskProfilesDialog> createState() => _TaskProfilesDialogState();
}

class _TaskProfilesDialogState extends ConsumerState<TaskProfilesDialog> {
  ModelTask _task = ModelTask.analysis;
  ServiceRoute _route = ServiceRoute.chatCompletions;
  String? _provider;
  final _model = TextEditingController();
  final _path = TextEditingController();
  final _header = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _model.dispose();
    _path.dispose();
    _header.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    final task = _task;
    final profiles = await ref
        .read(taskProfileRepositoryProvider)
        .load(widget.projectId);
    if (!mounted || task != _task) return;
    final p = profiles.where((p) => p.task == _task).firstOrNull;
    setState(() {
      _provider = p?.providerId;
      _route =
          p?.route ??
          (_task == ModelTask.synthesis
              ? ServiceRoute.native
              : ServiceRoute.chatCompletions);
      _model.text = p?.model ?? '';
      _path.text = p?.endpointPath ?? '';
      _header.text = p?.apiKeyHeader ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providers = (ref.watch(ttsProvidersStreamProvider).value ?? [])
        .where((p) => _task == ModelTask.synthesis || p.supportsRoleAi)
        .toList();
    final selected =
        providers.where((p) => p.id == _provider).firstOrNull ??
        providers.firstOrNull;
    final routes = _task == ModelTask.synthesis
        ? [ServiceRoute.native, ServiceRoute.speech, ServiceRoute.realtime]
        : [ServiceRoute.chatCompletions, ServiceRoute.responses];
    return AlertDialog(
      title: Text(l.taskProfiles),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.taskProfilesHelp),
              DropdownButtonFormField<ModelTask>(
                initialValue: _task,
                items: [
                  DropdownMenuItem(
                    value: ModelTask.analysis,
                    child: Text(l.roleAnalysisStart),
                  ),
                  DropdownMenuItem(
                    value: ModelTask.casting,
                    child: Text(l.roleSuggestCast),
                  ),
                  DropdownMenuItem(
                    value: ModelTask.tone,
                    child: Text(l.roleSuggestTone),
                  ),
                  DropdownMenuItem(
                    value: ModelTask.synthesis,
                    child: Text(l.taskSynthesis),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) async {
                        setState(() {
                          _task = v!;
                          _route = _task == ModelTask.synthesis
                              ? ServiceRoute.native
                              : ServiceRoute.chatCompletions;
                        });
                        await _load();
                      },
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('$_task:${selected?.id}'),
                initialValue: selected?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.roleAnalysisProvider),
                items: [
                  for (final p in providers)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _provider = v),
              ),
              DropdownButtonFormField<ServiceRoute>(
                key: ValueKey('$_task:$_route'),
                initialValue: _route,
                decoration: InputDecoration(labelText: l.taskProtocol),
                items: [
                  for (final r in routes)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _route = v!),
              ),
              TextField(
                controller: _model,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l.roleAnalysisModel,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.manage_search),
                    onPressed: _busy || selected == null
                        ? null
                        : () async {
                            final value = await showDialog<String>(
                              context: context,
                              builder: (_) => ModelCapabilityPicker(
                                provider: selected,
                                route: _route,
                                feature: _task == ModelTask.synthesis
                                    ? 'speech'
                                    : _task == ModelTask.analysis
                                    ? roleAiToolCapability
                                    : 'text',
                              ),
                            );
                            if (value != null && mounted) _model.text = value;
                          },
                  ),
                ),
              ),
              TextField(
                controller: _path,
                enabled: !_busy && _route != ServiceRoute.native,
                decoration: InputDecoration(
                  labelText: l.taskEndpoint,
                  hintText:
                      'chat/completions · responses · audio/speech · realtime',
                ),
              ),
              TextField(
                controller: _header,
                enabled: !_busy && _route != ServiceRoute.native,
                decoration: InputDecoration(
                  labelText: l.taskKeyHeader,
                  hintText: selected?.roleAiKeyHeader,
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  widget.beforeChange?.call();
                  await ref
                      .read(taskProfileRepositoryProvider)
                      .remove(widget.projectId, _task);
                  if (mounted) await _load();
                },
          child: Text(l.taskUseDefaults),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: _busy || selected == null
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    widget.beforeChange?.call();
                    await ref
                        .read(taskProfileRepositoryProvider)
                        .save(
                          widget.projectId,
                          TaskProfile(
                            task: _task,
                            providerId: selected.id,
                            model: _model.text.trim(),
                            route: _route,
                            endpointPath:
                                _route == ServiceRoute.native ||
                                    _path.text.trim().isEmpty
                                ? null
                                : _path.text.trim(),
                            apiKeyHeader: _header.text.trim().isEmpty
                                ? selected.roleAiKeyHeader
                                : _header.text.trim(),
                          ),
                        );
                  } catch (e) {
                    if (mounted) setState(() => _error = '$e');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
