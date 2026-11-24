import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart';
import 'package:neiroha/data/services/phase_role_repository.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/data/services/novel/role_model_choice.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';
import 'package:neiroha/providers/novel_role_providers.dart';
import 'package:neiroha/providers/model_capability_providers.dart';
import 'role_assignment_dialog.dart';

class PhaseRoleAssignmentButton extends ConsumerStatefulWidget {
  const PhaseRoleAssignmentButton({
    super.key,
    required this.projectId,
    required this.controller,
    required this.enabled,
    required this.prepare,
    required this.beforeApply,
  });
  final String projectId;
  final TextEditingController controller;
  final bool enabled;
  final Future<void> Function() prepare, beforeApply;
  @override
  ConsumerState<PhaseRoleAssignmentButton> createState() =>
      _PhaseRoleAssignmentButtonState();
}

class _PhaseRoleAssignmentButtonState
    extends ConsumerState<PhaseRoleAssignmentButton> {
  bool _busy = false;
  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      await widget.prepare();
      final database = ref.read(databaseProvider);
      final skills = ref.read(roleSkillProfilesRepositoryProvider);
      final repository = PhaseRoleRepository(database, skills);
      final project = await database.getPhaseTtsProjectById(widget.projectId);
      if (project == null || project.scriptText != widget.controller.text) {
        throw StateError('Save the current script before analysis.');
      }
      final signature = await repository.signature(widget.projectId);
      final existingSegments = (await database.getPhaseTtsSegments(
        widget.projectId,
      )).length;
      final members = (await database.getBankMembers(
        project.bankId,
      )).map((m) => m.voiceAssetId).toSet();
      final voices = (await database.getAllVoiceAssets())
          .where((a) => a.enabled && members.contains(a.id))
          .toList();
      final providers = (await database.getAllProviders())
          .where(providerOffersLlm)
          .toList();
      final config = effectiveRoleProfile(
        (await skills.load()).active,
        await ref.read(aiCapabilityRouterProvider.future),
      );
      if (!mounted) return;
      final selection = await showDialog<RoleAssignmentSelection>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TextRoleAssignmentDialog(
          text: project.scriptText,
          voices: voices,
          providers: providers,
          config: config,
          queue: ref.read(ttsQueueServiceProvider),
          loadSkill: skills.loadSkill,
          capabilities: ref.read(capabilityRepositoryProvider),
          existingSegments: existingSegments,
        ),
      );
      if (selection == null || !mounted) return;
      await widget.beforeApply();
      await repository.apply(
        projectId: project.id,
        expectedSignature: signature,
        plan: selection.plan,
        voices: selection.voices,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (_, value, _) => OutlinedButton.icon(
          icon: const Icon(Icons.psychology_alt_outlined),
          label: Text(AppLocalizations.of(context).phaseAutoRoles),
          onPressed: widget.enabled && !_busy && value.text.trim().isNotEmpty
              ? _open
              : null,
        ),
      );
}
