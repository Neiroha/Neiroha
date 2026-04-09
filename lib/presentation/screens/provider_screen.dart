import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:q_vox_lab/data/adapters/tts_adapter.dart';
import 'package:q_vox_lab/data/database/app_database.dart' as db;
import 'package:q_vox_lab/domain/enums/adapter_type.dart';
import 'package:q_vox_lab/presentation/theme/app_theme.dart';
import 'package:q_vox_lab/providers/app_providers.dart';

/// Two-pane provider configuration screen.
///
/// Left:  ordered list of providers (active ones float to top, drag-to-reorder
///        within their group). Each row has an activation toggle.
/// Right: editor for the selected provider — name, base URL, key, model, and
///        a health-check button.
final _selectedProviderIdProvider = StateProvider<String?>((ref) => null);

class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersStreamProvider);
    final selectedId = ref.watch(_selectedProviderIdProvider);

    return providersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (providers) {
        // Auto-select the first provider if nothing selected and list is not empty.
        final effectiveSelectedId = selectedId ??
            (providers.isNotEmpty ? providers.first.id : null);
        final selected =
            providers.where((p) => p.id == effectiveSelectedId).firstOrNull;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: _ProviderListPane(
                providers: providers,
                selectedId: effectiveSelectedId,
                onSelect: (id) =>
                    ref.read(_selectedProviderIdProvider.notifier).state = id,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? _buildEmpty(context)
                  : _ProviderEditor(
                      key: ValueKey(selected.id),
                      provider: selected,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('Select or add a provider',
              style: TextStyle(
                  fontSize: 16, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

// ────────────────────────── Left Pane: List ───────────────────────────────

class _ProviderListPane extends ConsumerWidget {
  final List<db.TtsProvider> providers;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _ProviderListPane({
    required this.providers,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 12),
            child: Row(
              children: [
                Text('Providers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Add Provider',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: providers.isEmpty
                ? Center(
                    child: Text(
                      'No providers yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    buildDefaultDragHandles: false,
                    itemCount: providers.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final list = [...providers];
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      await ref
                          .read(databaseProvider)
                          .reorderProviders(list.map((p) => p.id).toList());
                    },
                    itemBuilder: (ctx, i) {
                      final p = providers[i];
                      return _ProviderRow(
                        key: ValueKey(p.id),
                        provider: p,
                        index: i,
                        isSelected: p.id == selectedId,
                        onTap: () => onSelect(p.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddProviderDialog(
        onAdd: (companion) async {
          final db_ = ref.read(databaseProvider);
          await db_.insertProvider(companion);
          ref.read(_selectedProviderIdProvider.notifier).state =
              companion.id.value;
        },
      ),
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  final db.TtsProvider provider;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderRow({
    super.key,
    required this.provider,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? AppTheme.accentColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: provider.enabled
                        ? AppTheme.accentColor.withValues(alpha: 0.2)
                        : AppTheme.surfaceBright,
                  ),
                  child: Icon(
                    provider.enabled
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 16,
                    color: provider.enabled
                        ? AppTheme.accentColor
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _adapterLabel(provider.adapterType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.enabled,
                  onChanged: (v) async {
                    await ref
                        .read(databaseProvider)
                        .updateProvider(provider.copyWith(enabled: v));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _adapterLabel(String type) {
  for (final t in AdapterType.values) {
    if (t.name == type) return t.displayName;
  }
  return type;
}

// ────────────────────────── Right Pane: Editor ───────────────────────────

class _ProviderEditor extends ConsumerStatefulWidget {
  final db.TtsProvider provider;
  const _ProviderEditor({super.key, required this.provider});

  @override
  ConsumerState<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends ConsumerState<_ProviderEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  late AdapterType _adapterType;

  bool _showKey = false;
  bool _checking = false;
  bool? _lastHealth;
  String? _healthError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.provider.name);
    _urlCtrl = TextEditingController(text: widget.provider.baseUrl);
    _keyCtrl = TextEditingController(text: widget.provider.apiKey);
    _modelCtrl = TextEditingController(text: widget.provider.defaultModelName);
    _adapterType = AdapterType.values.firstWhere(
      (t) => t.name == widget.provider.adapterType,
      orElse: () => AdapterType.openaiCompatible,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(databaseProvider).updateProvider(widget.provider.copyWith(
          name: _nameCtrl.text.trim(),
          adapterType: _adapterType.name,
          baseUrl: _urlCtrl.text.trim(),
          apiKey: _keyCtrl.text,
          defaultModelName: _modelCtrl.text.trim().isEmpty
              ? _adapterType.defaultModel
              : _modelCtrl.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saved'), duration: Duration(seconds: 1)));
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete provider?'),
        content: Text('"${widget.provider.name}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(databaseProvider).deleteProvider(widget.provider.id);
    if (mounted) {
      ref.read(_selectedProviderIdProvider.notifier).state = null;
    }
  }

  Future<void> _healthCheck() async {
    setState(() {
      _checking = true;
      _lastHealth = null;
      _healthError = null;
    });
    // Use the in-memory form values so the user can test before saving.
    final tmp = widget.provider.copyWith(
      adapterType: _adapterType.name,
      baseUrl: _urlCtrl.text.trim(),
      apiKey: _keyCtrl.text,
      defaultModelName: _modelCtrl.text.trim().isEmpty
          ? _adapterType.defaultModel
          : _modelCtrl.text.trim(),
    );
    try {
      final adapter = createAdapter(tmp);
      final ok = await adapter.healthCheck();
      if (mounted) setState(() => _lastHealth = ok);
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastHealth = false;
          _healthError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _adapterType.displayName,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
                color: Colors.redAccent,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<AdapterType>(
                decoration: const InputDecoration(labelText: 'Adapter Type'),
                initialValue: _adapterType,
                items: AdapterType.values
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _adapterType = v;
                    if (_modelCtrl.text.isEmpty) {
                      _modelCtrl.text = v.defaultModel;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keyCtrl,
                obscureText: !_showKey,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _modelCtrl,
                decoration: InputDecoration(
                  labelText: 'Default Model Name',
                  hintText: _adapterType.defaultModel,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _healthCheck,
                    icon: _checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Health Check'),
                  ),
                  const SizedBox(width: 14),
                  if (_lastHealth != null)
                    _HealthBadge(
                        ok: _lastHealth!, errorMessage: _healthError),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final bool ok;
  final String? errorMessage;
  const _HealthBadge({required this.ok, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green : Colors.redAccent;
    return Tooltip(
      message: ok ? 'Endpoint reachable' : (errorMessage ?? 'Unreachable'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              ok ? 'Healthy' : 'Failed',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── Add Provider Dialog ───────────────────────────

class _AddProviderDialog extends StatefulWidget {
  final Future<void> Function(db.TtsProvidersCompanion) onAdd;
  const _AddProviderDialog({required this.onAdd});

  @override
  State<_AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends State<_AddProviderDialog> {
  final _nameCtrl = TextEditingController();
  AdapterType _selectedType = AdapterType.openaiCompatible;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Provider'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AdapterType>(
              decoration: const InputDecoration(labelText: 'Adapter Type'),
              initialValue: _selectedType,
              items: AdapterType.values
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(t.displayName)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'You can configure the URL, API key, and model after creation.',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final id = const Uuid().v4();
            await widget.onAdd(db.TtsProvidersCompanion(
              id: Value(id),
              name: Value(_nameCtrl.text.trim()),
              adapterType: Value(_selectedType.name),
              baseUrl: Value(''),
              apiKey: const Value(''),
              defaultModelName: Value(_selectedType.defaultModel),
              enabled: const Value(false),
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
