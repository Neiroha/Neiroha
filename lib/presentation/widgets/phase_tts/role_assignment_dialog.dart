import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/novel/role_skill_repository.dart';
import 'package:neiroha/data/services/novel/text_role_analysis_service.dart';
import 'package:neiroha/data/services/capabilities/capability_repository.dart';
import 'package:neiroha/data/services/tts_queue_service.dart';
import 'package:neiroha/domain/novel/dubbing_intent.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_skill_profile.dart';
import 'package:neiroha/domain/novel/text_role_plan.dart';
import 'package:neiroha/domain/text/novel_semantic_segmenter.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../novel_roles/dubbing_intent_fields.dart';
import '../novel_roles/model_discover_button.dart';
import '../novel_roles/role_labels.dart';
import 'role_assignment_editor.dart';
import 'role_assignment_preview.dart';

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
    this.existingSegments = 0,
    this.analysisService,
    this.capabilities,
  });
  final String text;
  final List<db.VoiceAsset> voices;
  final List<db.TtsProvider> providers;
  final RoleSkillProfile config;
  final TtsQueueService queue;
  final RoleSkillLoader loadSkill;
  final int existingSegments;
  final TextRoleAnalysisService? analysisService;
  final CapabilityRepository? capabilities;
  @override
  State<TextRoleAssignmentDialog> createState() =>
      _TextRoleAssignmentDialogState();
}

class _TextRoleAssignmentDialogState extends State<TextRoleAssignmentDialog> {
  final _notes = TextEditingController();
  late final _model = TextEditingController(text: widget.config.model);
  late String? _providerId =
      widget.providers.any((p) => p.id == widget.config.providerId)
      ? widget.config.providerId
      : widget.providers.firstOrNull?.id;
  late final _segmentCount =
      widget.text.length > TextRoleAnalysisService.maxTextLength
      ? null
      : NovelSemanticSegmenter.split(widget.text).length;
  final _voices = <String, String?>{};
  final _edits = <int, TextRoleUnit>{};
  final _added = <StoryCharacter>[];
  DubbingMode _mode = DubbingMode.automatic;
  TtsCancelToken? _active;
  RoleAnalysisProgress? _progress;
  TextRolePlan? _original;
  String? _error;
  bool _showPreview = false, _stopped = false;

  @override
  void dispose() {
    _active?.cancel();
    _notes.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final provider = widget.providers
        .where((p) => p.id == _providerId)
        .firstOrNull;
    final model = _model.text.trim();
    if (provider == null || model.isEmpty || _active != null) return;
    final token = TtsCancelToken();
    setState(() {
      _active = token;
      _progress = null;
      _error = null;
      _stopped = false;
    });
    try {
      final service =
          widget.analysisService ??
          TextRoleAnalysisService(
            widget.queue,
            loadSkill: widget.loadSkill,
            capabilities: widget.capabilities,
          );
      final plan = await service.analyze(
        text: widget.text,
        intent: dubbingIntent(_mode, _notes.text),
        provider: provider,
        model: model,
        cancellation: token,
        onProgress: (progress) {
          if (mounted && !token.isCancelled) {
            setState(() => _progress = progress);
          }
        },
      );
      if (mounted && !token.isCancelled) {
        setState(() {
          _original = plan;
          _showPreview = true;
          _edits.clear();
          _added.clear();
          _voices.clear();
          for (final character in plan.characters) {
            final matches = widget.voices
                .where(
                  (voice) =>
                      voice.name == character.name ||
                      character.aliases.contains(voice.name),
                )
                .toList();
            if (matches.length == 1) _voices[character.id] = matches.single.id;
          }
        });
      }
    } on TtsCancelledException {
      token.cancel();
    } catch (error) {
      if (mounted && !token.isCancelled) {
        final detail = '$error';
        setState(
          () => _error = provider.apiKey.isEmpty
              ? detail
              : detail.replaceAll(provider.apiKey, '[REDACTED]'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _stopped = token.isCancelled;
          _active = null;
        });
      }
    }
  }

  TextRolePlan _draft(TextRolePlan original) => TextRolePlan(
    text: original.text,
    skillDigest: original.skillDigest,
    calls: original.calls,
    scene: original.scene,
    characters: [...original.characters, ..._added],
    units: [
      for (final (index, unit) in original.units.indexed) _edits[index] ?? unit,
    ],
  );

  Future<void> _edit(int index, TextRolePlan draft) async {
    final original = _original!.units[index];
    final result = await showDialog<RoleAssignmentEdit>(
      context: context,
      builder: (_) => RoleAssignmentEditor(
        original: original,
        unit: draft.units[index],
        characters: draft.characters,
        before: index > 0 ? draft.units[index - 1].text : null,
        after: index + 1 < draft.units.length
            ? draft.units[index + 1].text
            : null,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      var id = result.characterId;
      if (result.newName case final name?) {
        id = const Uuid().v4();
        _added.add(StoryCharacter(id: id, projectId: '', name: name));
      }
      if (original.characterId == id && original.kind == result.kind) {
        _edits.remove(index);
      } else {
        _edits[index] = original.withAssignment(result.kind, id);
      }
    });
  }

  Future<void> _apply(TextRolePlan plan) async {
    final l = AppLocalizations.of(context);
    final unresolved = plan.units.where((u) => u.needsReview).length;
    if (widget.existingSegments > 0 || unresolved > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.phaseRoleApply),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.existingSegments > 0)
                Text(l.phaseRoleReplaceExisting(widget.existingSegments)),
              if (unresolved > 0) Text(l.phaseRoleKeepUncertain(unresolved)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.uiBack),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.uiApply),
            ),
          ],
        ),
      );
      if (!mounted || confirm != true) return;
    }
    final keys = plan.units.map((u) => u.voiceKey).toSet();
    Navigator.pop(
      context,
      RoleAssignmentSelection(plan, {
        for (final entry in _voices.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final plan = _original;
    final preview = _showPreview && plan != null ? _draft(plan) : null;
    final token = _active;
    final busy = token != null;
    final count = _segmentCount;
    final withinLimit =
        count != null &&
        count > 0 &&
        count <= TextRoleAnalysisService.maxSegments;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _active?.cancel();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
              constraints.maxHeight - MediaQuery.viewInsetsOf(context).vertical;
          final buttonTextScale =
              MediaQuery.textScalerOf(context).scale(14) / 14;
          final compact =
              availableHeight < 380 ||
              constraints.maxWidth < 300 * buttonTextScale;

          Widget action(
            String label,
            IconData icon,
            VoidCallback? onPressed, {
            bool primary = false,
            bool showIcon = false,
          }) {
            if (compact) {
              return primary
                  ? IconButton.filled(
                      tooltip: label,
                      onPressed: onPressed,
                      icon: Icon(icon),
                    )
                  : IconButton(
                      tooltip: label,
                      onPressed: onPressed,
                      icon: Icon(icon),
                    );
            }
            if (primary && showIcon) {
              return FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(label),
              );
            }
            return primary
                ? FilledButton(onPressed: onPressed, child: Text(label))
                : TextButton(onPressed: onPressed, child: Text(label));
          }

          final actions = [
            if (token != null)
              action(
                l.phaseRoleStop,
                Icons.stop,
                token.isCancelled ? null : () => setState(token.cancel),
              ),
            if (!busy && preview == null && plan != null)
              action(
                l.phaseRoleBackToPreview,
                Icons.preview_outlined,
                () => setState(() => _showPreview = true),
              ),
            if (!busy && preview == null)
              action(
                l.phaseRoleAnalyze,
                Icons.auto_awesome_outlined,
                withinLimit &&
                        _providerId != null &&
                        _model.text.trim().isNotEmpty
                    ? _analyze
                    : null,
                primary: true,
                showIcon: true,
              ),
            if (preview != null) ...[
              action(
                l.phaseRoleAdjustIntent,
                Icons.tune,
                () => setState(() => _showPreview = false),
              ),
              action(
                l.phaseRoleApply,
                Icons.check,
                () => _apply(preview),
                primary: true,
              ),
            ],
          ];

          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 16,
              vertical: compact ? 8 : 16,
            ),
            titlePadding: compact
                ? const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4)
                : null,
            contentPadding: compact
                ? const EdgeInsets.fromLTRB(16, 0, 16, 8)
                : null,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    preview == null
                        ? l.phaseAutoRoles
                        : l.phaseRolePreviewTitle,
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                  ),
                ),
                if (compact) ...actions,
                if (!busy)
                  IconButton(
                    tooltip: l.uiClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: preview == null && !busy ? 360 : 600,
              child: preview == null
                  ? _setup(l, count, enabled: !busy)
                  : RoleAssignmentPreview(
                      key: ObjectKey(plan),
                      plan: preview,
                      voices: widget.voices,
                      voiceByRole: _voices,
                      setVoice: (key, voice) =>
                          setState(() => _voices[key] = voice),
                      editUnit: (index) => _edit(index, preview),
                    ),
            ),
            actions: compact ? null : actions,
          );
        },
      ),
    );
  }

  Widget _setup(AppLocalizations l, int? count, {required bool enabled}) {
    final theme = Theme.of(context), progress = _progress;
    final token = _active;
    final selected = widget.providers
        .where((p) => p.id == _providerId)
        .firstOrNull;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (count == null || count > TextRoleAnalysisService.maxSegments)
          Text(
            l.phaseRoleLengthLimit,
            style: TextStyle(color: theme.colorScheme.error),
          )
        else
          Text(
            l.phaseRoleInputSummary(count),
            style: theme.textTheme.bodyMedium,
          ),
        if (token != null) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress != null && progress.processed > 0
                ? progress.processed / progress.total
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            token.isCancelled
                ? l.phaseRoleStopping
                : progress == null
                ? l.phaseRolePreparing
                : roleAnalysisStageLabel(l, progress.stage),
            style: theme.textTheme.titleSmall,
          ),
          if (progress != null)
            Text(
              l.phaseRoleProgress(
                progress.processed,
                progress.total,
                progress.calls,
              ),
            ),
        ],
        if (_stopped) Text(l.phaseRoleStopped),
        if (_error case final error?)
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 16),
        DubbingIntentFields(
          mode: _mode,
          onChanged: (mode) => setState(() => _mode = mode),
          notes: _notes,
          enabled: enabled,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.phaseRoleConnectionSettings),
          subtitle: Text(
            '${selected?.name ?? l.roleAnalysisOffline} · ${_model.text}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          initiallyExpanded: widget.providers.isEmpty,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _providerId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.roleAnalysisProvider),
              items: [
                for (final p in widget.providers)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled
                  ? (v) => setState(() => _providerId = v)
                  : null,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _model,
              enabled: enabled,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.roleAnalysisModel,
                suffixIcon: RoleModelDiscoverButton(
                  provider: selected,
                  enabled: enabled,
                  onSelected: (model) => setState(() => _model.text = model),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
