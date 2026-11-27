import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:uuid/uuid.dart';

/// Capabilities a vendor's plugin offers before any account is set up.
Set<AiCapability> adapterCapabilities(AdapterType type) {
  try {
    return pluginForAdapterType(type.name).capabilities;
  } catch (_) {
    return const {};
  }
}

/// Pick a vendor from cards listing what each can do, then name it.
class AddProviderDialog extends StatefulWidget {
  const AddProviderDialog({super.key, required this.onAdd});
  final Future<void> Function(db.TtsProvidersCompanion) onAdd;

  @override
  State<AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<AddProviderDialog> {
  final _name = TextEditingController();
  final _platform = PlatformCapabilities.current();
  AdapterType? _type;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final type = _type;
    if (type == null) return;
    final name = _name.text.trim().isEmpty
        ? _platform.displayNameForAdapter(type)
        : _name.text.trim();
    await widget.onAdd(
      db.TtsProvidersCompanion(
        id: Value(const Uuid().v4()),
        name: Value(name),
        adapterType: Value(type.name),
        baseUrl: const Value(''),
        apiKey: const Value(''),
        defaultModelName: Value(defaultSpeechModelForPlatform(type, _platform)),
        enabled: const Value(false),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final types = _platform.visibleAdapterTypes;
    return AlertDialog(
      title: Text(l.uiAddProvider),
      content: SizedBox(
        width: 640,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.provAddPick, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  const minCardWidth = 160.0;
                  final columns =
                      ((constraints.maxWidth + spacing) /
                              (minCardWidth + spacing))
                          .floor()
                          .clamp(1, 4);
                  return GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent:
                          MediaQuery.textScalerOf(context).scale(44) + 56,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                    ),
                    children: [
                      for (final t in types)
                        _VendorCard(
                          name: _platform.displayNameForAdapter(t),
                          caps: adapterCapabilities(t),
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l.uiName,
                hintText: _type == null
                    ? null
                    : _platform.displayNameForAdapter(_type!),
              ),
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 6),
            Text(
              l.provAddHint,
              style: TextStyle(
                fontSize: 12,
                color: context.fg.withValues(alpha: 0.38),
              ),
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
          onPressed: _type == null ? null : _create,
          child: Text(l.uiCreate),
        ),
      ],
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.name,
    required this.caps,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final Set<AiCapability> caps;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: selected
          ? AppTheme.accentColor.withValues(alpha: 0.18)
          : context.colors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppTheme.accentColor : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final cap in AiCapability.values)
                    if (caps.contains(cap))
                      Tooltip(
                        message: capabilityLabel(l, cap),
                        child: Icon(
                          capabilityIcon(cap),
                          size: 14,
                          color: AppTheme.accentColor.withValues(alpha: 0.8),
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
