import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';

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
        final effectiveSelectedId =
            selectedId ?? (providers.isNotEmpty ? providers.first.id : null);
        final selected = providers
            .where((p) => p.id == effectiveSelectedId)
            .firstOrNull;

        return ResizableSplitPane(
          initialLeftFraction: 0.35,
          left: _ProviderListPane(
            providers: providers,
            selectedId: effectiveSelectedId,
            onSelect: (id) =>
                ref.read(_selectedProviderIdProvider.notifier).state = id,
          ),
          rightBuilder: (_) => selected == null
              ? _buildEmpty(context)
              : _ProviderEditor(key: ValueKey(selected.id), provider: selected),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Select or add a provider',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
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
                Text(
                  'Providers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _adapterLabel(provider.adapterType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
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
  late final TextEditingController _concurrencyCtrl;
  late final TextEditingController _rpmCtrl;
  late final TextEditingController _rpdCtrl;
  late final TextEditingController _tpmCtrl;
  late final TextEditingController _tpdCtrl;
  late AdapterType _adapterType;

  bool _showKey = false;
  bool _checking = false;
  bool? _lastHealth;
  String? _healthError;

  // Model & voice list management
  // For hasSeparateModelAndVoice adapters, _models holds model entries and
  // _voices holds voice entries. For others, _models holds everything.
  List<db.ModelBinding> _models = [];
  List<db.ModelBinding> _voices = [];
  bool _fetchingModels = false;

  /// Whether a model key is a TTS model (vs LLM/ASR/multimodal).
  bool _isTtsModelKey(String modelKey) {
    if (_adapterType == AdapterType.gptSovits) return true;
    final k = modelKey.toLowerCase();
    return k.contains('tts') ||
        k.contains('gpt-sovits') ||
        k.contains('sovits') ||
        k.contains('speech-synthesis') ||
        k.contains('voiceclone') ||
        k.contains('voicedesign') ||
        k.endsWith('-voice');
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.provider.name);
    _urlCtrl = TextEditingController(text: widget.provider.baseUrl);
    _keyCtrl = TextEditingController(text: widget.provider.apiKey);
    _modelCtrl = TextEditingController(text: widget.provider.defaultModelName);
    _concurrencyCtrl = TextEditingController(
      text: widget.provider.maxConcurrency.toString(),
    );
    _rpmCtrl = TextEditingController(
      text: widget.provider.requestsPerMinute?.toString() ?? '',
    );
    _rpdCtrl = TextEditingController(
      text: widget.provider.requestsPerDay?.toString() ?? '',
    );
    _tpmCtrl = TextEditingController(
      text: widget.provider.tokensPerMinute?.toString() ?? '',
    );
    _tpdCtrl = TextEditingController(
      text: widget.provider.tokensPerDay?.toString() ?? '',
    );
    _adapterType = AdapterType.values.firstWhere(
      (t) => t.name == widget.provider.adapterType,
      orElse: () => AdapterType.openaiCompatible,
    );
    _loadModels();
  }

  Future<void> _loadModels() async {
    final db_ = ref.read(databaseProvider);
    if (_adapterType.hasSeparateModelAndVoice) {
      final models = await db_.getModelEntriesForProvider(widget.provider.id);
      final voices = await db_.getVoiceEntriesForProvider(widget.provider.id);
      if (mounted) {
        setState(() {
          _models = models;
          _voices = voices;
        });
      }
    } else {
      final bindings = await db_.getBindingsForProvider(widget.provider.id);
      if (mounted) {
        setState(() => _models = bindings);
      }
    }
  }

  Future<void> _fetchModelsFromApi() async {
    setState(() => _fetchingModels = true);
    try {
      final tmp = widget.provider.copyWith(
        adapterType: _adapterType.name,
        baseUrl: _urlCtrl.text.trim(),
        apiKey: _keyCtrl.text,
        defaultModelName: _modelCtrl.text.trim().isEmpty
            ? _adapterType.defaultModel
            : _modelCtrl.text.trim(),
      );
      final adapter = createAdapter(tmp);
      final db_ = ref.read(databaseProvider);

      // Fetch models
      final fetchedModels = await adapter.getModels();
      if (!mounted) return;
      if (fetchedModels.isNotEmpty) {
        final fetchedModelKeys = fetchedModels.map((m) => m.id).toSet();
        for (final existing in _models) {
          if (!fetchedModelKeys.contains(existing.modelKey)) {
            await db_.deleteBinding(existing.id);
          }
        }
      }
      final existingModels = fetchedModels.isNotEmpty
          ? _models
                .where((m) => fetchedModels.any((f) => f.id == m.modelKey))
                .map((m) => m.modelKey)
                .toSet()
          : _models.map((m) => m.modelKey).toSet();
      for (final m in fetchedModels) {
        if (!existingModels.contains(m.id)) {
          await db_.insertBinding(
            db.ModelBindingsCompanion(
              id: Value(const Uuid().v4()),
              providerId: Value(widget.provider.id),
              modelKey: Value(m.id),
              // model entries use default supportedTaskModes = ''
            ),
          );
        }
      }

      // For adapters with separate voices, also fetch and cache voices.
      if (_adapterType.hasSeparateModelAndVoice) {
        final fetchedVoices = await adapter.getSpeakers();
        if (!mounted) return;
        if (fetchedVoices.isNotEmpty) {
          final fetchedVoiceKeys = fetchedVoices.toSet();
          for (final existing in _voices) {
            if (!fetchedVoiceKeys.contains(existing.modelKey)) {
              await db_.deleteBinding(existing.id);
            }
          }
        }
        final existingVoices = fetchedVoices.isNotEmpty
            ? _voices
                  .where((v) => fetchedVoices.contains(v.modelKey))
                  .map((v) => v.modelKey)
                  .toSet()
            : _voices.map((v) => v.modelKey).toSet();
        for (final v in fetchedVoices) {
          if (!existingVoices.contains(v)) {
            await db_.insertBinding(
              db.ModelBindingsCompanion(
                id: Value(const Uuid().v4()),
                providerId: Value(widget.provider.id),
                modelKey: Value(v),
                supportedTaskModes: const Value('voice'),
              ),
            );
          }
        }
      }

      await _loadModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to fetch: $e')));
      }
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _addEntryManually({required bool isVoice}) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVoice ? 'Add Voice' : 'Add Model'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isVoice ? 'Voice name' : 'Model name / ID',
            hintText: isVoice ? 'e.g. alloy' : 'e.g. tts-1-hd',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    final db_ = ref.read(databaseProvider);
    await db_.insertBinding(
      db.ModelBindingsCompanion(
        id: Value(const Uuid().v4()),
        providerId: Value(widget.provider.id),
        modelKey: Value(name),
        supportedTaskModes: Value(isVoice ? 'voice' : ''),
      ),
    );
    await _loadModels();
  }

  Future<void> _removeEntry(String bindingId) async {
    await ref.read(databaseProvider).deleteBinding(bindingId);
    await _loadModels();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _concurrencyCtrl.dispose();
    _rpmCtrl.dispose();
    _rpdCtrl.dispose();
    _tpmCtrl.dispose();
    _tpdCtrl.dispose();
    super.dispose();
  }

  int _parseConcurrency() {
    final parsed = int.tryParse(_concurrencyCtrl.text.trim());
    return (parsed ?? 1).clamp(1, 64).toInt();
  }

  int? _parseOptionalLimit(TextEditingController controller) {
    final parsed = int.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .updateProvider(
          widget.provider.copyWith(
            name: _nameCtrl.text.trim(),
            adapterType: _adapterType.name,
            baseUrl: _urlCtrl.text.trim(),
            apiKey: _keyCtrl.text,
            defaultModelName: _modelCtrl.text.trim().isEmpty
                ? _adapterType.defaultModel
                : _modelCtrl.text.trim(),
            maxConcurrency: _parseConcurrency(),
            requestsPerMinute: Value(_parseOptionalLimit(_rpmCtrl)),
            requestsPerDay: Value(_parseOptionalLimit(_rpdCtrl)),
            tokensPerMinute: Value(_parseOptionalLimit(_tpmCtrl)),
            tokensPerDay: Value(_parseOptionalLimit(_tpdCtrl)),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _duplicate() async {
    final nameCtrl = TextEditingController(
      text: '${widget.provider.name} (Copy)',
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Provider'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (newName == null || newName.isEmpty) return;
    final db_ = ref.read(databaseProvider);
    final newProvider = await db_.duplicateProvider(
      widget.provider.id,
      newName,
    );
    if (mounted) {
      ref.read(_selectedProviderIdProvider.notifier).state = newProvider.id;
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
            child: const Text('Cancel'),
          ),
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

  String _baseUrlHint(AdapterType type) => switch (type) {
    AdapterType.azureTts =>
      'https://eastasia.tts.speech.microsoft.com  (or region name)',
    AdapterType.systemTts => '(not required)',
    AdapterType.gptSovits => 'http://localhost:9880',
    AdapterType.cosyvoice => 'http://localhost:9880',
    AdapterType.voxcpm2Native => 'http://127.0.0.1:8000',
    _ => 'https://api.openai.com/v1',
  };

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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _adapterType.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _duplicate,
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Duplicate as Template',
              ),
              const SizedBox(width: 4),
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
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    )
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
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: _baseUrlHint(_adapterType),
                  helperText: _adapterType == AdapterType.azureTts
                      ? 'Accepts region name, tts.speech.microsoft.com, or api.cognitive.microsoft.com URL'
                      : null,
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
              // ── Default Model Name (only for adapters without model/voice query) ──
              if (_adapterType.showDefaultModelField) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Default Model Name',
                    hintText: _adapterType.defaultModel,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Queue & Rate Limits',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Concurrency 1 is safest for local GPU TTS. Leave rate fields blank for unlimited.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _LimitField(
                    controller: _concurrencyCtrl,
                    label: 'Concurrency',
                    helperText: '1-64',
                    width: 150,
                  ),
                  _LimitField(
                    controller: _rpmCtrl,
                    label: 'RPM',
                    helperText: 'Requests / min',
                  ),
                  _LimitField(
                    controller: _rpdCtrl,
                    label: 'RPD',
                    helperText: 'Requests / day',
                  ),
                  _LimitField(
                    controller: _tpmCtrl,
                    label: 'TPM',
                    helperText: 'Approx tokens / min',
                  ),
                  _LimitField(
                    controller: _tpdCtrl,
                    label: 'TPD',
                    helperText: 'Approx tokens / day',
                  ),
                ],
              ),
              // ── Model / Voice sections ──
              if (_adapterType.supportsModelQuery ||
                  _adapterType.supportsVoiceQuery) ...[
                const SizedBox(height: 20),

                // ── Models + Voices section ──
                if (_adapterType.supportsModelQuery ||
                    _adapterType.supportsVoiceQuery) ...[
                  Row(
                    children: [
                      Text(
                        _adapterType.hasSeparateModelAndVoice
                            ? 'Models & Voices'
                            : 'Voices',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _fetchingModels ? null : _fetchModelsFromApi,
                        icon: _fetchingModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.cloud_download_rounded,
                                size: 16,
                              ),
                        label: Text(
                          _adapterType.hasSeparateModelAndVoice
                              ? 'Fetch All'
                              : 'Fetch',
                        ),
                      ),
                      if (_adapterType.supportsModelQuery)
                        TextButton.icon(
                          onPressed: () => _addEntryManually(isVoice: false),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Model'),
                        ),
                      if (_adapterType.supportsVoiceQuery)
                        TextButton.icon(
                          onPressed: () => _addEntryManually(isVoice: true),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Voice'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_adapterType.hasSeparateModelAndVoice) ...[
                    // ── Models (TTS with type badge, non-TTS with capability badges) ──
                    if (_models.isEmpty && _voices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'No models or voices yet. Use "Fetch All" or add manually.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    else ...[
                      // TTS models — voices are NOT nested here because the
                      // schema has no model→voice link; rendering them per
                      // model would duplicate every voice under every TTS row.
                      ..._models
                          .where((m) => _isTtsModelKey(m.modelKey))
                          .map(
                            (m) => _TtsModelRow(
                              model: m,
                              onDelete: () => _removeEntry(m.id),
                            ),
                          ),
                      // Non-TTS models with capability badges
                      ..._models
                          .where((m) => !_isTtsModelKey(m.modelKey))
                          .map(
                            (m) => _NonTtsModelRow(
                              model: m,
                              onDelete: () => _removeEntry(m.id),
                            ),
                          ),
                      // Custom Voices — flat section. Built-in voices for known
                      // TTS models (e.g. MiMo V2/V2.5) are rendered inline
                      // under each model row, so this section holds only
                      // user-added or API-fetched voices. Schema has no
                      // model→voice link, so we can't attribute them.
                      if (_voices.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Custom Voices',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        ..._voices.map(
                          (v) => _BindingRow(
                            key: ValueKey(v.id),
                            label: v.modelKey,
                            icon: Icons.record_voice_over_rounded,
                            onDelete: () => _removeEntry(v.id),
                          ),
                        ),
                      ],
                    ],
                  ] else ...[
                    // ── Voice-only adapters (Azure, System) ──
                    if (_models.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'No voices yet. Use "Fetch" to get available voices.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    else
                      ..._models.map(
                        (v) => _BindingRow(
                          key: ValueKey(v.id),
                          label: v.modelKey,
                          icon: Icons.record_voice_over_rounded,
                          onDelete: () => _removeEntry(v.id),
                        ),
                      ),
                  ],
                ],
              ],
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Health Check'),
                  ),
                  const SizedBox(width: 14),
                  if (_lastHealth != null)
                    _HealthBadge(ok: _lastHealth!, errorMessage: _healthError),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LimitField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String helperText;
  final double width;

  const _LimitField({
    required this.controller,
    required this.label,
    required this.helperText,
    this.width = 170,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, helperText: helperText),
      ),
    );
  }
}

// ─────────────────── Shared binding row widget ───────────────────────────────

class _BindingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onDelete;

  const _BindingRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── TTS model group (model + its voices) ─────────────────

class _TtsModelRow extends StatefulWidget {
  final db.ModelBinding model;
  final VoidCallback onDelete;

  const _TtsModelRow({required this.model, required this.onDelete});

  @override
  State<_TtsModelRow> createState() => _TtsModelRowState();
}

class _TtsModelRowState extends State<_TtsModelRow> {
  bool _expanded = false;

  /// Detect TTS model type label from model name.
  String get _typeLabel {
    final k = widget.model.modelKey.toLowerCase();
    if (k.contains('voiceclone') || k.contains('clone')) return 'Clone';
    if (k.contains('voicedesign') || k.contains('design')) return 'Design';
    return 'Preset';
  }

  /// Built-in voices for this model (e.g., MiMo V2/V2.5). Empty if unknown.
  List<String> get _builtInVoices =>
      ChatCompletionsTtsAdapter.builtInVoicesForMimoModel(
        widget.model.modelKey,
      );

  @override
  Widget build(BuildContext context) {
    final voices = _builtInVoices;
    final hasBuiltIns = voices.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — tap to expand if built-ins exist.
            InkWell(
              onTap: hasBuiltIns
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 16,
                      color: Colors.purpleAccent.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.model.modelKey,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasBuiltIns) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${voices.length} voices',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purpleAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    if (hasBuiltIns)
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Built-in voices, shown when expanded.
            if (hasBuiltIns && _expanded)
              Padding(
                padding: const EdgeInsets.only(
                  left: 28,
                  right: 12,
                  bottom: 8,
                  top: 2,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: voices
                      .map(
                        (v) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            v,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Non-TTS model row with capability badges ─────────────

class _NonTtsModelRow extends StatelessWidget {
  final db.ModelBinding model;
  final VoidCallback onDelete;

  const _NonTtsModelRow({required this.model, required this.onDelete});

  /// Infer capability badges from model name.
  List<String> get _capabilities {
    final k = model.modelKey.toLowerCase();
    final caps = <String>[];
    if (k.contains('omni') ||
        RegExp(r'mimo-v2(\.5)?$').hasMatch(k) ||
        k.contains('-vision') ||
        (k.contains('gpt-4o') && !k.contains('transcribe'))) {
      caps.addAll(['LLM', 'ASR']);
    } else {
      caps.add('LLM');
    }
    return caps;
  }

  Color _badgeColor(String cap) => switch (cap) {
    'LLM' => Colors.blueAccent,
    'ASR' => Colors.greenAccent,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBright,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.smart_toy_rounded,
              size: 16,
              color: Colors.blueAccent.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(model.modelKey, style: const TextStyle(fontSize: 13)),
            ),
            ..._capabilities.map(
              (cap) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeColor(cap).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cap,
                    style: TextStyle(
                      fontSize: 10,
                      color: _badgeColor(cap).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
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
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
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
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.displayName)),
                  )
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
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final id = const Uuid().v4();
            await widget.onAdd(
              db.TtsProvidersCompanion(
                id: Value(id),
                name: Value(_nameCtrl.text.trim()),
                adapterType: Value(_selectedType.name),
                baseUrl: Value(''),
                apiKey: const Value(''),
                defaultModelName: Value(_selectedType.defaultModel),
                enabled: const Value(false),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
