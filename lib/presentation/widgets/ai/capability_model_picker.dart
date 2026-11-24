import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/capability_router.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';

/// "Connection · model" for a routed model.
String routedLabel(RoutedModel<CapabilityModel> routed) =>
    '${connectionName(routed.connection)} · ${routed.model.descriptor.label}';

/// The automatic entry's value inside the menu.
const _automatic = ('', '');

/// A searchable dropdown over every (connection, model) that serves [cap],
/// in the capability's automatic order and led by an automatic entry. Type
/// to filter. A choice that is no longer served stays listed, marked
/// unavailable, so it does not silently turn into the automatic entry.
class CapabilityModelPicker extends StatefulWidget {
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
    this.badge,
    this.allowCustom = false,
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

  /// Trailing mark for a listed model, e.g. its tool-calling support.
  final Widget? Function(ProviderConnection, ModelDescriptor)? badge;

  /// Offer the typed text as a model id on each connection, for models the
  /// catalog does not list.
  final bool allowCustom;

  @override
  State<CapabilityModelPicker> createState() => _CapabilityModelPickerState();
}

class _CapabilityModelPickerState extends State<CapabilityModelPicker> {
  final _text = TextEditingController();
  String _selectedLabel = '';

  @override
  void initState() {
    super.initState();
    if (widget.allowCustom) _text.addListener(_onText);
  }

  // The menu also writes the field while it builds; rebuild after that.
  void _onText() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cap = widget.cap;
    final router = widget.router;
    final current = widget.value;
    final served = router.serving(cap);
    final choices = [
      for (final c in served)
        for (final m in router.modelsOf(c, cap)) (c, m),
    ];
    final missing =
        current != null &&
        !choices.any((x) => x.$1.id == current.$1 && x.$2.id == current.$2);
    final typed = _text.text.trim();
    final custom =
        widget.allowCustom &&
        typed.isNotEmpty &&
        typed != _selectedLabel &&
        !choices.any((x) => x.$2.id == typed);
    final entries = <DropdownMenuEntry<(String, String)>>[
      DropdownMenuEntry(
        value: _automatic,
        label: widget.automaticLabel ?? l.capAutomatic,
        leadingIcon: const Icon(Icons.auto_mode_rounded, size: 18),
      ),
      if (missing)
        DropdownMenuEntry(
          value: current,
          label: l.capModelUnavailable(current.$2),
          leadingIcon: const Icon(Icons.warning_amber_rounded, size: 18),
          style: MenuItemButton.styleFrom(foregroundColor: Colors.orangeAccent),
        ),
      for (final (c, m) in choices)
        DropdownMenuEntry(
          value: (c.id, m.id),
          label: '${connectionName(c)} · ${m.label}',
          trailingIcon: widget.badge?.call(c, m),
        ),
      if (custom)
        for (final c in served)
          DropdownMenuEntry(
            value: (c.id, typed),
            label: l.capUseCustomModel(typed, connectionName(c)),
            leadingIcon: const Icon(Icons.edit_rounded, size: 18),
          ),
    ];
    final initial = current ?? _automatic;
    _selectedLabel = entries
        .firstWhere((e) => e.value == initial, orElse: () => entries.first)
        .label;
    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<(String, String)>(
        key: ValueKey((cap, current)),
        controller: _text,
        initialSelection: initial,
        enabled: widget.enabled,
        width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
        menuHeight: 360,
        // Match the app's filled fields instead of the menu's outline.
        inputDecorationTheme: Theme.of(context).inputDecorationTheme,
        label: widget.label == null ? null : Text(widget.label!),
        errorText: widget.errorText,
        enableFilter: true,
        requestFocusOnTap: true,
        trailingIcon: const Icon(Icons.expand_more_rounded),
        selectedTrailingIcon: const Icon(Icons.expand_less_rounded),
        // The field shows the current choice: list everything until the
        // user types something else.
        filterCallback: (entries, filter) {
          final q = filter.trim().toLowerCase();
          if (q.isEmpty || filter == _selectedLabel) return entries;
          return [
            for (final e in entries)
              if (e.value == _automatic || e.label.toLowerCase().contains(q)) e,
          ];
        },
        onSelected: (v) {
          if (v == null || v == initial) return;
          widget.onChanged(v == _automatic ? null : v);
        },
        dropdownMenuEntries: entries,
      ),
    );
  }
}
