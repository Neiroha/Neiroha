import 'package:flutter/material.dart';
import 'package:neiroha/domain/novel/role_models.dart';
import 'package:neiroha/domain/novel/role_scene_state.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class NovelRoleSceneSummary extends StatelessWidget {
  const NovelRoleSceneSummary({
    super.key,
    required this.scene,
    required this.roles,
    this.showHelp = true,
  });
  final RoleSceneState scene;
  final NovelRoleSnapshot roles;
  final bool showHelp;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String name(String? id) =>
        roles.characters.where((c) => c.id == id).firstOrNull?.name ??
        l.rolePending;
    String names(List<String> ids) => ids.map(name).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHelp)
            Text(
              l.roleSceneTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          Text('${l.roleSceneFirstPerson}：${name(scene.firstPersonId)}'),
          if (scene.presentCharacterIds.isNotEmpty)
            Text('${l.roleScenePresent}：${names(scene.presentCharacterIds)}'),
          if (scene.nestedNarratorIds.isNotEmpty)
            Text('${l.roleSceneNested}：${names(scene.nestedNarratorIds)}'),
          if (scene.evidence.isNotEmpty) Text(scene.evidence),
          if (showHelp)
            Text(l.roleSceneHelp, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
