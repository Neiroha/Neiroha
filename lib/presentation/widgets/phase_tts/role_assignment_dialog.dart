import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/role_skill_repository.dart';
import 'package:neiroha/data/services/novel/text_role_analysis_service.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import '../novel_roles/role_labels.dart';

class RoleAssignmentSelection {
  const RoleAssignmentSelection(this.plan, this.voices);
  final TextRolePlan plan;
  final Map<String, String?> voices;
}

class TextRoleAssignmentDialog extends StatefulWidget {
  const TextRoleAssignmentDialog({
    super.key,
    required this.text,
    required this.voices,
    required this.providers,
    required this.config,
    required this.queue,
    required this.loadSkill,
  });
  final String text;
  final List<db.VoiceAsset> voices;
  final List<db.TtsProvider> providers;
  final RoleSkillProfile config;
  final TtsQueueService queue;
  final RoleSkillLoader loadSkill;
  @override
  State<TextRoleAssignmentDialog> createState() =>
      _TextRoleAssignmentDialogState();
}

class _TextRoleAssignmentDialogState extends State<TextRoleAssignmentDialog> {
  final _intent = TextEditingController();
  late final _model = TextEditingController(text: widget.config.model);
  late String? _providerId =
      widget.providers.any((p) => p.id == widget.config.providerId)
      ? widget.config.providerId
      : widget.providers.firstOrNull?.id;
  final _cancellation = TtsCancelToken();
  final _voices = <String, String?>{};
  TextRolePlan? _plan;
  Object? _error;
  bool _busy = false;
  @override
  void dispose() {
    _cancellation.cancel();
    _intent.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final provider = widget.providers
        .where((p) => p.id == _providerId)
        .firstOrNull;
    if (provider == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final plan =
          await TextRoleAnalysisService(
            widget.queue,
            loadSkill: widget.loadSkill,
          ).analyze(
            text: widget.text,
            intent: _intent.text,
            provider: provider,
            model: _model.text.trim(),
            cancellation: _cancellation,
          );
      if (mounted) {
        setState(() {
          _plan = plan;
          for (final c in plan.characters) {
            final matches = widget.voices
                .where((v) => v.name == c.name || c.aliases.contains(v.name))
                .toList();
            if (matches.length == 1) _voices[c.id] = matches.single.id;
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), plan = _plan;
    final names = {
      for (final c in plan?.characters ?? <StoryCharacter>[]) c.id: c.name,
    };
    String name(TextRoleUnit u) =>
        names[u.characterId] ??
        (u.kind == NovelSegmentKind.narrator
            ? l.roleNarrator
            : u.kind == NovelSegmentKind.system
            ? l.roleSystem
            : l.phaseRoleUnknown);
    return PopScope(
      onPopInvokedWithResult: (_, _) => _cancellation.cancel(),
      child: AlertDialog(
        title: Text(l.phaseAutoRoles),
        content: SizedBox(
          width: 800,
          height: 600,
          child: plan == null
              ? ListView(
                  children: [
                    Text(l.phaseRoleReviewHint),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _providerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l.roleAnalysisProvider,
                      ),
                      items: [
                        for (final p in widget.providers)
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _providerId = v),
                    ),
                    TextField(
                      controller: _model,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: l.roleAnalysisModel,
                      ),
                    ),
                    TextField(
                      controller: _intent,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        labelText: l.phaseRoleIntent,
                        hintText: l.phaseRoleIntentHint,
                      ),
                    ),
                    Text(l.phaseRoleStatus),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Text(
                        '$_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                )
              : ListView(
                  children: [
                    Text(l.phaseRoleReviewHint),
                    Text('${plan.calls} ${l.roleAnalysisCalls}'),
                    for (final key in plan.units.map((u) => u.voiceKey).toSet())
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: DropdownButtonFormField<String>(
                          initialValue: _voices[key] ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: name(
                              plan.units.firstWhere((u) => u.voiceKey == key),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Text(l.phaseRoleNoVoice),
                            ),
                            for (final v in widget.voices)
                              DropdownMenuItem(
                                value: v.id,
                                child: Text(v.name),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _voices[key] = v == '' ? null : v),
                        ),
                      ),
                    const Divider(),
                    for (final unit in plan.units)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(unit.text),
                        subtitle: Text(
                          '${name(unit)} · ${roleKindLabel(l, unit.kind)} · ${roleReviewLabel(l, unit.review)}\n${unit.reason}',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _cancellation.cancel();
              Navigator.pop(context);
            },
            child: Text(l.uiCancel),
          ),
          if (plan == null)
            FilledButton(
              onPressed: _busy || _providerId == null ? null : _analyze,
              child: Text(l.phaseRoleAnalyze),
            ),
          if (plan != null)
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                RoleAssignmentSelection(plan, Map.of(_voices)),
              ),
              child: Text(l.phaseRoleApply),
            ),
        ],
      ),
    );
  }
}
