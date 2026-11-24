import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';

/// "Connection · model" for a routed model.
String routedLabel(RoutedModel<CapabilityModel> routed) =>
    '${connectionName(routed.connection)} · ${routed.model.descriptor.label}';

/// One dropdown over every (connection, model) that serves [cap], led by an
/// automatic entry. A choice that is no longer served stays listed, marked
/// unavailable, so it does not silently turn into the automatic entry.
class CapabilityModelPicker extends StatelessWidget {
  const CapabilityModelPicker({
    super.key,
    required this.cap,
    required this.router,
    required this.value,
    required this.onChanged,
    this.label,
    this.automaticLabel,
    this.errorText,
    this.enabled = true,
  });

  final AiCapability cap;
  final CapabilityRouter router;

  /// (connection id, model id); null is the automatic entry.
  final (String, String)? value;
  final ValueChanged<(String, String)?> onChanged;
  final String? label;

  /// Text of the automatic entry; defaults to "Automatic (first available)".
  final String? automaticLabel;

  /// Shown under the field, e.g. when nothing serves the capability.
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final choices = [
      for (final c in router.serving(cap))
        for (final m in router.modelsOf(c, cap))
          ((c.id, m.id), '${connectionName(c)} · ${m.label}'),
    ];
    final current = value;
    final missing =
        current != null && !choices.any((choice) => choice.$1 == current);
    return DropdownButtonFormField<(String, String)?>(
      key: ValueKey((cap, current)),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        errorText: errorText,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            automaticLabel ?? l.capAutomatic,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (missing)
          DropdownMenuItem(
            value: current,
            child: Text(
              l.capModelUnavailable(current.$2),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        for (final (id, text) in choices)
          DropdownMenuItem(
            value: id,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
