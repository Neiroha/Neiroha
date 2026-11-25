import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Whether [lane] sets any limit of its own.
bool laneHasLimits(db.ConnectionCapability lane) =>
    lane.maxConcurrency != null ||
    lane.requestsPerMinute != null ||
    lane.requestsPerDay != null ||
    lane.tokensPerMinute != null ||
    lane.tokensPerDay != null;

/// Edits one connection × capability lane; empty fields inherit.
class CapabilityLimitsDialog extends ConsumerStatefulWidget {
  const CapabilityLimitsDialog({
    super.key,
    required this.title,
    required this.connectionId,
    required this.capability,
    this.lane,
  });
  final String title;
  final String connectionId;
  final AiCapability capability;
  final db.ConnectionCapability? lane;

  @override
  ConsumerState<CapabilityLimitsDialog> createState() =>
      _CapabilityLimitsDialogState();
}

class _CapabilityLimitsDialogState
    extends ConsumerState<CapabilityLimitsDialog> {
  late final _fields = [
    widget.lane?.maxConcurrency,
    widget.lane?.requestsPerMinute,
    widget.lane?.requestsPerDay,
    widget.lane?.tokensPerMinute,
    widget.lane?.tokensPerDay,
  ].map((v) => TextEditingController(text: v?.toString() ?? '')).toList();

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Value<int?> _value(int i) {
    final n = int.tryParse(_fields[i].text.trim());
    return Value(n == null || n <= 0 ? null : n);
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .upsertConnectionCapability(
          db.ConnectionCapabilitiesCompanion(
            connectionId: Value(widget.connectionId),
            capability: Value(widget.capability.name),
            enabled: Value(widget.lane?.enabled ?? true),
            maxConcurrency: _value(0),
            requestsPerMinute: _value(1),
            requestsPerDay: _value(2),
            tokensPerMinute: _value(3),
            tokensPerDay: _value(4),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [l.capConcurrency, l.capRpm, l.capRpd, l.capTpm, l.capTpd];
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.capLimitsHint,
              style: TextStyle(
                fontSize: 12,
                color: context.fg.withValues(alpha: 0.54),
              ),
            ),
            const SizedBox(height: 8),
            for (final (i, label) in labels.indexed)
              TextField(
                controller: _fields[i],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: label,
                  hintText: l.capInherited,
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
        FilledButton(onPressed: _save, child: Text(l.uiSave)),
      ],
    );
  }
}

/// Asks for a model id (and display name); returns `(id, name)`.
class AddModelDialog extends StatefulWidget {
  const AddModelDialog({super.key});

  @override
  State<AddModelDialog> createState() => _AddModelDialogState();
}

class _AddModelDialogState extends State<AddModelDialog> {
  final _id = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    Navigator.pop(context, (id, _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.capAddModel),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              autofocus: true,
              decoration: InputDecoration(labelText: l.capModelId),
              onSubmitted: (_) => _submit(),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l.capDisplayName),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.uiCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.uiSave)),
      ],
    );
  }
}

/// Asks for a model id and adds it under [cap] of [connection], unless the
/// connection cannot serve that id.
Future<void> addCapabilityModel(
  BuildContext context,
  WidgetRef ref,
  ProviderConnection connection,
  AiCapability cap,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final entry = await showDialog<(String, String)>(
    context: context,
    builder: (_) => const AddModelDialog(),
  );
  if (entry == null) return;
  final (modelId, name) = entry;
  if (connection.describe(cap, modelId) == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.capModelRejected(modelId))),
    );
    return;
  }
  await ref
      .read(databaseProvider)
      .upsertProviderModel(
        db.ProviderModelsCompanion.insert(
          id: const Uuid().v4(),
          connectionId: connection.id,
          modelId: modelId,
          capability: cap.name,
          displayName: Value(name.isEmpty ? null : name),
        ),
      );
}
