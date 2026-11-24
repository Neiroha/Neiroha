import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'package:neiroha/providers/model_capability_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/core/provider_connection.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/data/ai/registry/model_badges.dart';
import 'package:neiroha/data/services/capabilities/model_retirement.dart';
import 'package:neiroha/presentation/widgets/ai/model_retirement_widgets.dart';
import 'package:neiroha/data/ai/registry/plugin_registry.dart';
import 'package:neiroha/presentation/widgets/voice_chip_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/form_pair.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/tts_provider_model_row.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (providers) {
        // Auto-select the first provider if nothing selected and list is not empty.
        final effectiveSelectedId =
            selectedId ?? (providers.isNotEmpty ? providers.first.id : null);
        final selected = providers
            .where((p) => p.id == effectiveSelectedId)
            .firstOrNull;

        return ResizableSplitPane(
          initialLeftFraction: 0.35,
          compactRightIcon: Icons.tune_rounded,
          compactRightLabel: AppLocalizations.of(context).uiDetails,
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
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).uiSelectOrAddAProvider,
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
          WindowDragArea(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context).navProviders,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: AppLocalizations.of(context).uiAddProvider,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: providers.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context).uiNoProvidersYet,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    buildDefaultDragHandles: false,
                    itemCount: providers.length,
                    onReorderItem: (oldIndex, newIndex) async {
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
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final adapterType = _adapterTypeFor(provider.adapterType);
    final supported =
        adapterType != null && capabilities.supportsTtsAdapter(adapterType);
    final l10n = AppLocalizations.of(context);

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
                SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: provider.enabled && supported
                        ? AppTheme.accentColor.withValues(alpha: 0.2)
                        : AppTheme.surfaceBright,
                  ),
                  child: Icon(
                    !supported
                        ? Icons.block_rounded
                        : provider.enabled
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    size: 16,
                    color: provider.enabled && supported
                        ? AppTheme.accentColor
                        : (!supported ? Colors.redAccent : Colors.grey),
                  ),
                ),
                SizedBox(width: 10),
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
                        _adapterLabel(provider.adapterType, capabilities),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      if (!supported)
                        Text(
                          l10n.uiUnavailableOnThisPlatform,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: provider.enabled && supported,
                  onChanged: supported
                      ? (v) async {
                          await ref
                              .read(databaseProvider)
                              .updateProvider(provider.copyWith(enabled: v));
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

AdapterType? _adapterTypeFor(String type) {
  for (final t in AdapterType.values) {
    if (t.name == type) return t;
  }
  return null;
}

String _adapterLabel(String type, PlatformCapabilities capabilities) {
  final adapterType = _adapterTypeFor(type);
  if (adapterType == null) return type;
  return capabilities.displayNameForAdapter(adapterType);
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

  String get _defaultModel => defaultSpeechModelForPlatform(
    _adapterType,
    ref.read(platformCapabilitiesProvider),
  );

  /// The saved provider, for catalog-mounted capability badges.
  ProviderConnection? get _connection {
    try {
      return connectionForProvider(widget.provider);
    } catch (_) {
      return null;
    }
  }

  /// Fetched or hand-added voices not built into a listed TTS model.
  List<VoiceChipEntry> get _customVoices {
    final builtIn = builtInVoicesAcross(
      _adapterType,
      _models.map((m) => m.modelKey).where(_isTtsModelKey),
    );
    return [
      for (final v in _voices)
        if (!builtIn.contains(v.modelKey)) (label: v.modelKey, id: v.id),
    ];
  }

  /// Whether a model key is a TTS model (vs LLM/ASR/multimodal).
  bool _isTtsModelKey(String modelKey) {
    // The local launchers list voice sets; OpenAI uses its curated TTS models.
    if (_adapterType == AdapterType.gptSovits ||
        _adapterType == AdapterType.irodori ||
        _adapterType == AdapterType.rvc ||
        _adapterType == AdapterType.openaiTts) {
      return true;
    }
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
            ? _defaultModel
            : _modelCtrl.text.trim(),
      );
      await ref
          .read(providerModelInventoryProvider)
          .refresh(tmp, separateVoices: _adapterType.hasSeparateModelAndVoice);
      await _loadModels();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).uiFailedToFetch(e)),
          ),
        );
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
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(AppLocalizations.of(context).uiAdd),
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
                ? _defaultModel
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
        SnackBar(
          content: Text(AppLocalizations.of(context).uiSaved),
          duration: Duration(seconds: 1),
        ),
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
        title: Text(AppLocalizations.of(context).uiDuplicateProvider),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiNewName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text(AppLocalizations.of(context).uiDuplicate),
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
        title: Text(AppLocalizations.of(context).uiDeleteProvider),
        content: Text(
          AppLocalizations.of(context).uiWillBeRemoved(widget.provider.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).uiCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).uiDelete),
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
    AdapterType.gptSovits => 'http://127.0.0.1:9880',
    AdapterType.cosyvoice => 'http://127.0.0.1:9880',
    AdapterType.voxcpm2Native => 'http://127.0.0.1:8000',
    AdapterType.openaiTts => 'https://api.openai.com/v1',
    AdapterType.geminiTts => 'https://generativelanguage.googleapis.com',
    AdapterType.elevenLabs => 'https://api.elevenlabs.io',
    AdapterType.minimaxTts =>
      'https://api.minimax.io  (China: https://api.minimaxi.com)',
    AdapterType.indexTts => 'http://127.0.0.1:7860  (IndexTTS WebUI)',
    AdapterType.irodori => 'http://127.0.0.1:19000',
    AdapterType.rvc =>
      'http://127.0.0.1:19001  (Neiroha-RVC, voice conversion)',
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
          ? _defaultModel
          : _modelCtrl.text.trim(),
    );
    try {
      final adapter = createAdapter(tmp);
      final timeout = await readHealthCheckTimeout(ref);
      final ok = await adapter.healthCheck().timeout(
        timeout,
        onTimeout: () => false,
      );
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
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final adapterSupported = capabilities.supportsTtsAdapter(_adapterType);
    final adapterLabel = capabilities.displayNameForAdapter(_adapterType);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WindowDragArea(
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(24, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.provider.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        adapterSupported
                            ? adapterLabel
                            : '$adapterLabel · ${l10n.uiUnavailableOnThisPlatform}',
                        style: TextStyle(
                          fontSize: 12,
                          color: adapterSupported
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _duplicate,
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: AppLocalizations.of(context).uiDuplicateAsTemplate,
                ),
                SizedBox(width: 4),
                IconButton(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: AppLocalizations.of(context).uiDelete,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              if (!adapterSupported) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.uiAdapterUnavailableOnThisPlatform,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
              ],
              FormPair(
                first: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiName,
                  ),
                ),
                second: DropdownButtonFormField<AdapterType>(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiAdapterType,
                  ),
                  initialValue: _adapterType,
                  items: capabilities.editableAdapterTypes(_adapterType).map((
                    t,
                  ) {
                    final supported = capabilities.supportsTtsAdapter(t);
                    final label = capabilities.displayNameForAdapter(t);
                    return DropdownMenuItem(
                      value: t,
                      enabled: supported,
                      child: Text(
                        supported
                            ? label
                            : '$label (${l10n.uiUnavailableOnThisPlatform})',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _adapterType = v;
                      if (_modelCtrl.text.isEmpty) {
                        _modelCtrl.text = defaultSpeechModelForPlatform(
                          v,
                          capabilities,
                        );
                      }
                    });
                  },
                ),
              ),
              SizedBox(height: 12),
              FormPair(
                first: TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiBaseURL,
                    hintText: _baseUrlHint(_adapterType),
                    helperText: _adapterType == AdapterType.azureTts
                        ? 'Accepts region name, tts.speech.microsoft.com, or api.cognitive.microsoft.com URL'
                        : null,
                  ),
                ),
                second: TextField(
                  controller: _keyCtrl,
                  obscureText: !_showKey,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiAPIKey,
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
              ),
              SizedBox(height: 14),
              // ── Default Model Name (only for adapters without model/voice query) ──
              if (_adapterType.showDefaultModelField) ...[
                TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).uiDefaultModelName,
                    hintText: _defaultModel,
                  ),
                ),
              ],
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context).uiQueueRateLimits,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                AppLocalizations.of(
                  context,
                ).uiConcurrency1IsSafestForLocalGPUTTSLeaveRateFieldsBlank,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _LimitField(
                    controller: _concurrencyCtrl,
                    label: AppLocalizations.of(context).uiConcurrency,
                    helperText: '1-64',
                    width: 110,
                  ),
                  _LimitField(
                    controller: _rpmCtrl,
                    label: 'RPM',
                    helperText: AppLocalizations.of(context).uiRequestsMin,
                  ),
                  _LimitField(
                    controller: _rpdCtrl,
                    label: 'RPD',
                    helperText: AppLocalizations.of(context).uiRequestsDay,
                  ),
                  _LimitField(
                    controller: _tpmCtrl,
                    label: 'TPM',
                    helperText: AppLocalizations.of(context).uiApproxTokensMin,
                  ),
                  _LimitField(
                    controller: _tpdCtrl,
                    label: 'TPD',
                    helperText: AppLocalizations.of(context).uiApproxTokensDay,
                  ),
                ],
              ),
              // ── Model / Voice sections ──
              if (_adapterType.supportsModelQuery ||
                  _adapterType.supportsVoiceQuery) ...[
                SizedBox(height: 20),

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
                        onPressed: !adapterSupported || _fetchingModels
                            ? null
                            : _fetchModelsFromApi,
                        icon: _fetchingModels
                            ? SizedBox(
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
                          onPressed: adapterSupported
                              ? () => _addEntryManually(isVoice: false)
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(AppLocalizations.of(context).uiAddModel),
                        ),
                      if (_adapterType.supportsVoiceQuery)
                        TextButton.icon(
                          onPressed: adapterSupported
                              ? () => _addEntryManually(isVoice: true)
                              : null,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(AppLocalizations.of(context).uiAddVoice),
                        ),
                    ],
                  ),
                  SizedBox(height: 4),
                  if (_adapterType.hasSeparateModelAndVoice) ...[
                    // ── Models (TTS with type badge, non-TTS with capability badges) ──
                    if (_models.isEmpty && _voices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).uiNoModelsOrVoicesYetUseFetchAllOrAddManually,
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
                            (m) => TtsProviderModelRow(
                              key: ValueKey(m.id),
                              model: m,
                              webBlock: capabilities.isWeb
                                  ? browserSpeechModelBlock(
                                      _adapterType.name,
                                      m.modelKey,
                                      baseUrl: _urlCtrl.text,
                                    )
                                  : null,
                              voices: builtInVoicesFor(
                                _adapterType,
                                m.modelKey,
                              ),
                              shutdownAt: retiringDescriptor(
                                _connection,
                                m.modelKey,
                              )?.shutdownAt,
                              onDelete: () => _removeEntry(m.id),
                            ),
                          ),
                      // Non-TTS models with capability badges
                      ..._models
                          .where((m) => !_isTtsModelKey(m.modelKey))
                          .map(
                            (m) => _NonTtsModelRow(
                              model: m,
                              badges: modelBadges(m.modelKey, _connection),
                              shutdownAt: retiringDescriptor(
                                _connection,
                                m.modelKey,
                              )?.shutdownAt,
                              onDelete: () => _removeEntry(m.id),
                            ),
                          ),
                      // Account / custom voices; voices a listed TTS model
                      // ships with are already nested under that model.
                      if (_customVoices.isNotEmpty) ...[
                        SizedBox(height: 8),
                        VoiceGroupRow(
                          title: AppLocalizations.of(context).uiCustomVoices,
                          voices: _customVoices,
                          onDelete: _removeEntry,
                        ),
                      ],
                    ],
                  ] else ...[
                    // ── Voice-only adapters (Azure, System) ──
                    if (_models.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).uiNoVoicesYetUseFetchToGetAvailableVoices,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    else
                      // One engine, many voices (Azure lists hundreds).
                      VoiceGroupRow(
                        title: AppLocalizations.of(
                          context,
                        ).voiceEngineVoices(_adapterType.displayName),
                        icon: Icons.mic_rounded,
                        voices: [
                          for (final v in _models)
                            (label: v.modelKey, id: v.id),
                        ],
                        onDelete: _removeEntry,
                      ),
                  ],
                ],
              ],
              SizedBox(height: 24),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(AppLocalizations.of(context).uiSave),
                  ),
                  SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: !adapterSupported || _checking
                        ? null
                        : _healthCheck,
                    icon: _checking
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite_rounded, size: 18),
                    label: Text(AppLocalizations.of(context).uiHealthCheck),
                  ),
                  SizedBox(width: 14),
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
    this.width = 140,
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

class _NonTtsModelRow extends StatelessWidget {
  final db.ModelBinding model;
  final VoidCallback onDelete;

  final List<String> badges;
  final String? shutdownAt;

  const _NonTtsModelRow({
    required this.model,
    required this.onDelete,
    required this.badges,
    this.shutdownAt,
  });

  Color _badgeColor(String cap) => switch (cap) {
    'LLM' => Colors.blueAccent,
    'ASR' => Colors.greenAccent,
    'Realtime' || 'Translate' => Colors.orangeAccent,
    'Music' => Colors.pinkAccent,
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
            SizedBox(width: 8),
            Expanded(
              child: Text(model.modelKey, style: const TextStyle(fontSize: 13)),
            ),
            ...badges.map(
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
            if (shutdownAt case final date?) RetirementChip(shutdownAt: date),
            SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
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
    final l10n = AppLocalizations.of(context);
    final color = ok ? Colors.green : Colors.redAccent;
    return Tooltip(
      message: ok ? l10n.uiReachable : (errorMessage ?? l10n.uiUnreachable),
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
            SizedBox(width: 6),
            Text(
              ok ? l10n.uiReachable : l10n.uiFailed,
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
    final capabilities = PlatformCapabilities.current();
    final adapterTypes = capabilities.visibleAdapterTypes;

    return AlertDialog(
      title: Text(AppLocalizations.of(context).uiAddProvider),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiName,
              ),
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<AdapterType>(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiAdapterType,
              ),
              initialValue: _selectedType,
              items: adapterTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(capabilities.displayNameForAdapter(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedType = v);
              },
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(
                context,
              ).uiYouCanConfigureTheURLAPIKeyAndModelAfterCreation,
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
          child: Text(AppLocalizations.of(context).uiCancel),
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
                defaultModelName: Value(
                  defaultSpeechModelForPlatform(_selectedType, capabilities),
                ),
                enabled: const Value(false),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context).uiCreate),
        ),
      ],
    );
  }
}
