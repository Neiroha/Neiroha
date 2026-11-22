import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/llm_model_picker.dart';

/// Opens the LLM picker for role tasks, which need tool calling.
class RoleModelDiscoverButton extends StatelessWidget {
  const RoleModelDiscoverButton({
    super.key,
    required this.provider,
    required this.enabled,
    required this.onSelected,
    this.current,
  });
  final db.TtsProvider? provider;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final connection = provider;
    return IconButton(
      icon: const Icon(Icons.manage_search),
      tooltip: AppLocalizations.of(context).modelDiscover,
      onPressed: !enabled || connection == null
          ? null
          : () async {
              final model = await showLlmModelPicker(
                context,
                providerId: connection.id,
                current: current,
                requireTools: true,
              );
              if (context.mounted && model != null) onSelected(model.id);
            },
    );
  }
}
