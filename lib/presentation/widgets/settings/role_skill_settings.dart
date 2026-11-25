import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:neiroha/data/services/novel/role_model_choice.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/novel/novel_role_skill.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import '../novel_roles/skill_stage_labels.dart';
import '../ai/capability_model_picker.dart';
import '../ai/llm_model_summary.dart';
import '../ai/role_tool_check.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

class RoleSkillSettingsCard extends ConsumerStatefulWidget {
  const RoleSkillSettingsCard({super.key});
  @override
  ConsumerState<RoleSkillSettingsCard> createState() =>
      _RoleSkillSettingsCardState();
}

class _RoleSkillSettingsCardState extends ConsumerState<RoleSkillSettingsCard> {
  RoleSkillConfiguration? _draft;
  NovelRoleSkill? _builtin;
  final _prompt = TextEditingController();
  String _stage = 'planner';
  Object? _error;
  bool _busy = false, _dirty = false;
  int _revision = 0;

  /// Bumped when the user picks a model: the new one is tested at once.
  int _verifyRound = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(roleSkillProfilesRepositoryProvider);
      final config = await repo.load(), builtin = await repo.builtin();
      if (mounted) {
        setState(() {
          _draft = config;
          _builtin = builtin;
          _refresh();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _refresh() {
    _prompt.text = _draft!.active.prompts[_stage] ?? _builtin!.prompt(_stage);
    _revision++;
  }

  void _replace(RoleSkillProfile p) {
    _draft = RoleSkillConfiguration(
      activeId: p.id,
      profiles: [for (final old in _draft!.profiles) old.id == p.id ? p : old],
    );
    _dirty = true;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(roleSkillProfilesRepositoryProvider).save(_draft!);
      if (mounted) setState(() => _dirty = false);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_draft == null || _builtin == null) {
      return _error != null
          ? Text('$_error')
          : const Center(child: CircularProgressIndicator());
    }
    final p = _draft!.active;
    final rows = ref.watch(ttsProvidersStreamProvider).value ?? const [];
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final follow = router?.resolve<CapabilityModel>(AiCapability.llm);
    final effective = effectiveRoleProfile(p, router);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.roleSkillSettingsHint),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('profile:$_revision'),
              initialValue: p.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.roleSkillProfile),
              items: [
                for (final profile in _draft!.profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    child: Text(
                      profile.id == 'default'
                          ? l.roleSkillDefault
                          : profile.name,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (id) => setState(() {
                      _draft = RoleSkillConfiguration(
                        activeId: id!,
                        profiles: _draft!.profiles,
                      );
                      _dirty = true;
                      _refresh();
                    }),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.roleSkillClone),
                  onPressed: _busy || _draft!.profiles.length >= 20
                      ? null
                      : () => setState(() {
                          final copy = RoleSkillProfile(
                            id: const Uuid().v4(),
                            name:
                                '${l.roleSkillProfile} ${_draft!.profiles.length + 1}',
                            model: p.model,
                            providerId: p.providerId,
                            prompts: {...p.prompts},
                          );
                          _draft = RoleSkillConfiguration(
                            activeId: copy.id,
                            profiles: [..._draft!.profiles, copy],
                          );
                          _dirty = true;
                          _refresh();
                        }),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(l.roleSkillRestoreProfile),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() {
                            _replace(RoleSkillProfile(id: p.id, name: p.name));
                            _refresh();
                          });
                          await _save();
                        },
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('name:${p.id}:$_revision'),
              initialValue: p.name,
              enabled: !_busy && p.id != 'default',
              maxLength: 100,
              decoration: InputDecoration(labelText: l.roleSkillProfileName),
              onChanged: (v) =>
                  setState(() => _replace(_draft!.active.copyWith(name: v))),
            ),
            if (router == null)
              const LinearProgressIndicator()
            else
              CapabilityModelPicker(
                cap: AiCapability.llm,
                router: router,
                value: p.providerId == null ? null : (p.providerId!, p.model),
                label: l.roleAnalysisModelPick,
                automaticLabel: follow == null
                    ? l.capFollowDefaultNone
                    : l.roleModelFollowDefault(routedLabel(follow)),
                allowCustom: true,
                enabled: !_busy,
                badge: (_, m) => toolCallingBadge(context, m.llm?.tools),
                onChanged: (v) => setState(() {
                  final current = _draft!.active;
                  _replace(
                    RoleSkillProfile(
                      id: current.id,
                      name: current.name,
                      model: v?.$2 ?? current.model,
                      providerId: v?.$1,
                      prompts: current.prompts,
                    ),
                  );
                  _verifyRound++;
                }),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                l.roleModelHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fg.withValues(alpha: 0.38),
                ),
              ),
            ),
            RoleToolCheck(
              key: ValueKey(
                '${effective.providerId}/${effective.model}/$_verifyRound',
              ),
              provider: rows
                  .where((r) => r.id == effective.providerId)
                  .firstOrNull,
              model: effective.model,
              verifyNow: _verifyRound > 0,
            ),
            LlmModelSummary(
              providerId: effective.providerId,
              modelId: effective.model,
            ),
            const Divider(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _stage,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.roleSkillNode),
              items: [
                for (final stage in NovelRoleSkill.stages)
                  DropdownMenuItem(
                    value: stage,
                    child: Text(roleSkillStageLabel(l, stage)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _stage = v!;
                      _refresh();
                    }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              enabled: !_busy,
              minLines: 8,
              maxLines: 16,
              maxLength: 16000,
              decoration: InputDecoration(
                labelText: l.roleSkillPrompt,
                alignLabelWithHint: true,
              ),
              onChanged: (v) => setState(
                () => _replace(
                  _draft!.active.copyWith(
                    prompts: {..._draft!.active.prompts, _stage: v},
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _replace(
                          _draft!.active.copyWith(
                            prompts: {..._draft!.active.prompts}
                              ..remove(_stage),
                          ),
                        );
                        _refresh();
                      }),
                child: Text(l.roleSkillRestoreNode),
              ),
            ),
            Text(
              '${_builtin!.name} ${_builtin!.version}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null)
              Text(
                '$_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || !_dirty ? null : _save,
              child: Text(l.roleSkillSave),
            ),
          ],
        ),
      ),
    );
  }
}
