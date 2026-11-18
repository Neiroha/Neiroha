import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/role_ai_connection.dart';
import 'package:neiroha/domain/capabilities/model_capability.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

import '../model_capability_picker.dart';

class RoleModelDiscoverButton extends StatelessWidget {
  const RoleModelDiscoverButton({
    super.key,
    required this.provider,
    required this.enabled,
    required this.onSelected,
  });
  final db.TtsProvider? provider;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final connection = provider;
    return IconButton(
      icon: const Icon(Icons.manage_search),
      tooltip: AppLocalizations.of(context).modelDiscover,
      onPressed: !enabled || connection == null
          ? null
          : () async {
              final model = await showDialog<String>(
                context: context,
                builder: (_) => ModelCapabilityPicker(
                  provider: connection,
                  route: ServiceRoute.chatCompletions,
                  feature: roleAiToolCapability,
                ),
              );
              if (context.mounted && model != null) onSelected(model);
            },
    );
  }
}
