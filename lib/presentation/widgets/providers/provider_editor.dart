import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/ai/capability_badges.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/presentation/widgets/settings/ai_capability_settings.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'provider_capability_tab.dart';
import 'provider_draft.dart';
import 'provider_hub.dart';
import 'provider_limits_tab.dart';
import 'provider_overview_tab.dart';
import 'provider_speech_tab.dart';

/// Editor of one provider row, one tab per capability it offers:
/// overview (account and health), each capability, then limits.
class ProviderEditor extends ConsumerStatefulWidget {
  const ProviderEditor({super.key, required this.provider, this.onBack});
  final db.TtsProvider provider;

  /// Shown as a back button on narrow windows, where the list is hidden.
  final VoidCallback? onBack;

  @override
  ConsumerState<ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends ConsumerState<ProviderEditor> {
  late final _draft = ProviderDraft(widget.provider);

  String get _defaultModel => defaultSpeechModelForPlatform(
    _draft.adapterType,
    ref.read(platformCapabilitiesProvider),
  );

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _adapterChanged(AdapterType type) => setState(() {
    _draft.adapterType = type;
    if (_draft.model.text.isEmpty) _draft.model.text = _defaultModel;
  });

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(databaseProvider)
        .updateProvider(_draft.row(widget.provider, _defaultModel));
    messenger.showSnackBar(
      SnackBar(content: Text(l.uiSaved), duration: const Duration(seconds: 1)),
    );
  }

  Future<String?> _askName(String title, String initial, String action) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l.uiNewName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return name == null || name.isEmpty ? null : name;
  }

  Future<void> _duplicate() async {
    final l = AppLocalizations.of(context);
    final name = await _askName(
      l.uiDuplicateProvider,
      '${widget.provider.name} (Copy)',
      l.uiDuplicate,
    );
    if (name == null) return;
    final copy = await ref
        .read(databaseProvider)
        .duplicateProvider(widget.provider.id, name);
    ref.read(selectedProviderIdProvider.notifier).state = copy.id;
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.uiDeleteProvider),
        content: Text(l.uiWillBeRemoved(widget.provider.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.uiCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.uiDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(databaseProvider).deleteProvider(widget.provider.id);
    ref.read(selectedProviderIdProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = ref.watch(platformCapabilitiesProvider);
    final supported = platform.supportsTtsAdapter(_draft.adapterType);
    final adapterLabel = platform.displayNameForAdapter(_draft.adapterType);
    final caps = [
      for (final cap in AiCapability.values)
        if (rowCapabilities(widget.provider).contains(cap)) cap,
    ];
    final p = widget.provider;
    final defaultModel = _defaultModel;

    // Opened from a capability elsewhere (the default-model page): start on
    // its tab.
    final focus = ref.watch(providerFocusCapabilityProvider);
    final focusIndex = focus == null ? -1 : caps.indexOf(focus);

    return DefaultTabController(
      key: ValueKey('${caps.join()}:$focus'),
      initialIndex: focusIndex + 1,
      length: caps.length + 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WindowDragArea(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: EdgeInsets.fromLTRB(
                widget.onBack == null ? 24 : 8,
                6,
                12,
                6,
              ),
              child: Row(
                children: [
                  if (widget.onBack case final back?)
                    IconButton(
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          supported
                              ? adapterLabel
                              : '$adapterLabel · '
                                    '${l.uiUnavailableOnThisPlatform}',
                          style: TextStyle(
                            fontSize: 12,
                            color: supported
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    tooltip: l.uiSave,
                  ),
                  IconButton(
                    onPressed: _duplicate,
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: l.uiDuplicateAsTemplate,
                  ),
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: l.uiDelete,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              Tab(text: l.provTabOverview),
              for (final cap in caps)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(capabilityIcon(cap), size: 16),
                      const SizedBox(width: 6),
                      Text(capabilityLabel(l, cap)),
                    ],
                  ),
                ),
              Tab(text: l.capLimits),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                ProviderOverviewTab(
                  provider: p,
                  draft: _draft,
                  defaultModel: defaultModel,
                  onAdapterChanged: _adapterChanged,
                  onSave: _save,
                ),
                for (final cap in caps)
                  cap == AiCapability.tts
                      ? ProviderSpeechTab(
                          provider: p,
                          draft: _draft,
                          defaultModel: defaultModel,
                          supported: supported,
                        )
                      : ProviderCapabilityTab(provider: p, cap: cap),
                ProviderLimitsTab(provider: p, draft: _draft, onSave: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
