import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/voice_chain_runner.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/synthesis/voice_chain.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/ai/vc_voice_field.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'components.dart';
import 'speech_check_view.dart';

/// Inspector section for a character's processing chain, drawn as a row of
/// composed functions: line → text steps → TTS → voice conversion → audio.
/// Changes save immediately.
class VoiceChainEditor extends ConsumerStatefulWidget {
  const VoiceChainEditor({super.key, required this.asset});
  final db.VoiceAsset asset;

  @override
  ConsumerState<VoiceChainEditor> createState() => _VoiceChainEditorState();
}

class _VoiceChainEditorState extends ConsumerState<VoiceChainEditor> {
  VoiceChain _chain = VoiceChain.empty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(VoiceChainEditor old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.asset.id;
    final chain = await VoiceChainHook.load(ref.read(databaseProvider), id);
    if (mounted && id == widget.asset.id) setState(() => _chain = chain);
  }

  Future<void> _store(List<VoiceChainStep> steps) async {
    final chain = VoiceChain(steps).normalized();
    setState(() => _chain = chain);
    await VoiceChainHook.save(
      ref.read(databaseProvider),
      widget.asset.id,
      chain,
    );
  }

  Future<void> _edit(VoiceChainStep step, {int? index}) async {
    final router = ref.read(aiCapabilityRouterProvider).value;
    if (router == null) return;
    final result = await showDialog<VoiceChainStep>(
      context: context,
      builder: (_) => _StepDialog(step, router),
    );
    if (result == null) return;
    final steps = [..._chain.steps];
    index == null ? steps.add(result) : steps[index] = result;
    await _store(steps);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _chain.steps;
    Widget node(int i) => _StepChip(
      step: steps[i],
      onTap: () => _edit(steps[i], index: i),
      onRemove: () => _store([...steps]..removeAt(i)),
    );
    const arrow = Icon(Icons.arrow_forward_rounded, size: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: VoiceCharacterSectionLabel(l.chainTitle)),
            PopupMenuButton<VoiceChainStepKind>(
              tooltip: l.chainAdd,
              icon: const Icon(Icons.add_link_rounded, size: 20),
              onSelected: (kind) => _edit(VoiceChainStep(kind: kind)),
              itemBuilder: (_) => [
                for (final kind in VoiceChainStepKind.values)
                  PopupMenuItem(
                    value: kind,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_icon(kind), size: 18),
                      title: Text(_kindLabel(l, kind)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Text(
          l.chainHint,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Terminal(Icons.notes_rounded, l.chainInput),
            for (final (i, s) in steps.indexed)
              if (s.kind.isText) ...[arrow, node(i)],
            arrow,
            _Terminal(
              Icons.record_voice_over_rounded,
              'TTS · ${widget.asset.name}',
              accent: true,
            ),
            for (final (i, s) in steps.indexed)
              if (!s.kind.isText) ...[arrow, node(i)],
            arrow,
            _Terminal(Icons.graphic_eq_rounded, l.chainOutput),
          ],
        ),
        if (_chain.audioSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l.chainNoStreaming,
            style: const TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
        ],
        if (_chain.audioSteps.any((s) => s.kind == VoiceChainStepKind.verify))
          SpeechCheckView(voiceAssetId: widget.asset.id),
      ],
    );
  }
}

IconData _icon(VoiceChainStepKind kind) => switch (kind) {
  VoiceChainStepKind.translate => Icons.translate_rounded,
  VoiceChainStepKind.rewrite => Icons.edit_note_rounded,
  VoiceChainStepKind.convert => Icons.transform_rounded,
  VoiceChainStepKind.trim => Icons.content_cut_rounded,
  VoiceChainStepKind.verify => Icons.hearing_rounded,
};

/// The capability serving a step; null for steps that need no model.
AiCapability? _capability(VoiceChainStepKind kind) => switch (kind) {
  VoiceChainStepKind.translate ||
  VoiceChainStepKind.rewrite => AiCapability.llm,
  VoiceChainStepKind.convert => AiCapability.vc,
  VoiceChainStepKind.verify => AiCapability.stt,
  VoiceChainStepKind.trim => null,
};

String _kindLabel(AppLocalizations l, VoiceChainStepKind kind) =>
    switch (kind) {
      VoiceChainStepKind.translate => l.chainTranslate,
      VoiceChainStepKind.rewrite => l.chainRewrite,
      VoiceChainStepKind.convert => l.chainConvert,
      VoiceChainStepKind.trim => l.chainTrim,
      VoiceChainStepKind.verify => l.chainVerify,
    };

String _stepLabel(AppLocalizations l, VoiceChainStep s) {
  if (!s.ready) return '${_kindLabel(l, s.kind)} · ${l.chainNeedsSetup}';
  return switch (s.kind) {
    VoiceChainStepKind.translate => l.chainTranslateTo(s.targetLanguage),
    VoiceChainStepKind.rewrite => l.chainRewrite,
    VoiceChainStepKind.convert => l.chainConvertTo(s.targetVoice),
    VoiceChainStepKind.trim => l.chainTrim,
    VoiceChainStepKind.verify => l.chainVerify,
  };
}

class _Terminal extends StatelessWidget {
  const _Terminal(this.icon, this.label, {this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: accent
          ? AppTheme.accentColor.withValues(alpha: 0.18)
          : AppTheme.surfaceBright,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.onTap,
    required this.onRemove,
  });
  final VoiceChainStep step;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = !step.ready
        ? Colors.orangeAccent
        : step.kind.isText
        ? Colors.lightBlueAccent
        : Colors.pinkAccent;
    return Opacity(
      opacity: step.enabled ? 1 : 0.45,
      child: InputChip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(_icon(step.kind), size: 14, color: color),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            _stepLabel(l, step),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        onPressed: onTap,
        onDeleted: onRemove,
        deleteButtonTooltipMessage: l.uiDelete,
      ),
    );
  }
}

class _StepDialog extends StatefulWidget {
  const _StepDialog(this.step, this.router);
  final VoiceChainStep step;
  final CapabilityRouter router;

  @override
  State<_StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends State<_StepDialog> {
  late final _language = TextEditingController(
    text: widget.step.targetLanguage,
  );
  late final _instruction = TextEditingController(
    text: widget.step.instruction,
  );
  late final _voice = TextEditingController(text: widget.step.targetVoice);
  late (String, String)? _model = widget.step.connectionId == null
      ? null
      : (widget.step.connectionId!, widget.step.modelId ?? '');
  late bool _enabled = widget.step.enabled;

  /// Models local servers list right now (RVC checkpoints), by connection.
  final Map<String, List<ModelDescriptor>> _live = {};

  @override
  void initState() {
    super.initState();
    final cap = _capability(widget.step.kind);
    if (cap == null) return;
    for (final c in widget.router.serving(cap)) {
      if (c is! LiveModelDiscovery) continue;
      unawaited(
        discoverModels(c, cap).then((models) {
          if (mounted) setState(() => _live[c.id] = models);
        }),
      );
    }
  }

  @override
  void dispose() {
    _language.dispose();
    _instruction.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final kind = widget.step.kind;
    final cap = _capability(kind);
    final models = [
      if (cap != null)
        for (final c in widget.router.serving(cap))
          for (final m in _live[c.id] ?? c.models(cap)) (c, m),
    ];
    final picked = models.any((e) => (e.$1.id, e.$2.id) == _model)
        ? _model
        : null;
    // Voice conversion has no default model to fall back on.
    final needsModel = kind == VoiceChainStepKind.convert;
    return AlertDialog(
      title: Row(
        children: [
          Icon(_icon(kind), size: 20),
          const SizedBox(width: 8),
          Text(_kindLabel(l, kind)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cap == null)
              const SizedBox.shrink()
            else if (models.isEmpty)
              Text(
                l.chainNoModels,
                style: const TextStyle(color: Colors.orangeAccent),
              )
            else
              DropdownButtonFormField<(String, String)?>(
                initialValue: picked,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.chainModel),
                items: [
                  if (!needsModel)
                    DropdownMenuItem(value: null, child: Text(l.liveDefault)),
                  for (final (c, m) in models)
                    DropdownMenuItem(
                      value: (c.id, m.id),
                      child: Text(
                        '${c.config.name.isEmpty ? c.plugin.displayName : c.config.name}'
                        ' · ${m.displayName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _model = v),
              ),
            const SizedBox(height: 12),
            switch (kind) {
              VoiceChainStepKind.translate => TextField(
                controller: _language,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.chainTargetLanguage,
                  hintText: l.chainTargetLanguageHint,
                ),
              ),
              VoiceChainStepKind.rewrite => TextField(
                controller: _instruction,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l.chainInstruction,
                  hintText: l.chainInstructionHint,
                ),
              ),
              VoiceChainStepKind.convert => VcVoiceField(
                controller: _voice,
                label: l.chainTargetVoice,
                connection: widget.router.connections
                    .where((c) => c.id == picked?.$1)
                    .firstOrNull,
                modelId: picked?.$2,
              ),
              VoiceChainStepKind.trim => Text(l.chainTrimHint),
              VoiceChainStepKind.verify => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _language,
                    decoration: InputDecoration(
                      labelText: l.chainVerifyLanguage,
                      hintText: l.chainTargetLanguageHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.chainVerifyHint,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            },
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.uiEnabled),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            VoiceChainStep(
              kind: kind,
              connectionId: picked?.$1,
              modelId: picked?.$2,
              targetLanguage: _language.text.trim(),
              instruction: _instruction.text.trim(),
              targetVoice: _voice.text.trim(),
              enabled: _enabled,
            ),
          ),
          child: Text(l.uiSave),
        ),
      ],
    );
  }
}
