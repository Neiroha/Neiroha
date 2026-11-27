import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/data/ai/registry/model_badges.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/capabilities/model_retirement.dart';
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/widgets/tts_provider_model_row.dart';
import 'package:neiroha/presentation/widgets/voice_chip_list.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/model_capability_providers.dart';
import 'package:uuid/uuid.dart';

import 'provider_draft.dart';
import 'provider_models.dart';
import 'package:neiroha/presentation/theme/app_colors.dart';

/// Speech synthesis of one connection: its TTS models with their built-in
/// voices, account and custom voices, fetch and manual entries.
class ProviderSpeechTab extends ConsumerStatefulWidget {
  const ProviderSpeechTab({
    super.key,
    required this.provider,
    required this.draft,
    required this.defaultModel,
    required this.supported,
  });
  final db.TtsProvider provider;
  final ProviderDraft draft;
  final String defaultModel;

  /// Whether this platform can run the adapter.
  final bool supported;

  @override
  ConsumerState<ProviderSpeechTab> createState() => _ProviderSpeechTabState();
}

class _ProviderSpeechTabState extends ConsumerState<ProviderSpeechTab> {
  bool _fetching = false;

  AdapterType get _type => widget.draft.adapterType;
  String get _id => widget.provider.id;

  void _reload() => ref.invalidate(providerBindingsProvider(_id));

  Future<void> _fetch() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetching = true);
    try {
      await ref
          .read(providerModelInventoryProvider)
          .refresh(
            widget.draft.connection(widget.provider, widget.defaultModel),
            separateVoices: _type.hasSeparateModelAndVoice,
          );
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.uiFailedToFetch(e))));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _addManually({required bool voice}) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(voice ? l.uiAddVoice : l.uiAddModel),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: voice ? 'alloy' : 'tts-1-hd'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.uiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.uiAdd),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await ref
        .read(databaseProvider)
        .insertBinding(
          db.ModelBindingsCompanion(
            id: Value(const Uuid().v4()),
            providerId: Value(_id),
            modelKey: Value(name),
            supportedTaskModes: Value(voice ? 'voice' : ''),
          ),
        );
    _reload();
  }

  Future<void> _remove(String bindingId) async {
    await ref.read(databaseProvider).deleteBinding(bindingId);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = ref.watch(platformCapabilitiesProvider);
    final connection = connectionOf(widget.provider);
    final bindings = ref.watch(providerBindingsProvider(_id)).value ?? const [];
    final separate = _type.hasSeparateModelAndVoice;
    final models = [
      for (final b in bindings)
        if (!separate || b.supportedTaskModes != 'voice') b,
    ];
    final voices = [
      for (final b in bindings)
        if (separate && b.supportedTaskModes == 'voice') b,
    ];
    final tts = [
      for (final m in models)
        if (isTtsModelKey(_type, m.modelKey)) m,
    ];
    // Fetched models no capability tab shows (embeddings, images…).
    final other = [
      for (final m in models)
        if (!isTtsModelKey(_type, m.modelKey) &&
            bindingCapability(m.modelKey, connection) == null)
          m,
    ];
    final builtIn = builtInVoicesAcross(_type, tts.map((m) => m.modelKey));
    final custom = [
      for (final v in voices)
        if (!builtIn.contains(v.modelKey)) (label: v.modelKey, id: v.id),
    ];
    final canQuery = _type.supportsModelQuery || _type.supportsVoiceQuery;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (connection != null)
          CapabilitySwitch(connectionId: _id, cap: AiCapability.tts),
        SectionHeader(
          separate ? l.capTts : l.voiceEngineVoices(_type.displayName),
          actions: [
            if (canQuery)
              TextButton.icon(
                onPressed: !widget.supported || _fetching ? null : _fetch,
                icon: _fetching
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(l.modelRefresh),
              ),
            if (_type.supportsModelQuery)
              TextButton.icon(
                onPressed: widget.supported
                    ? () => _addManually(voice: false)
                    : null,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.uiAddModel),
              ),
            if (_type.supportsVoiceQuery)
              TextButton.icon(
                onPressed: widget.supported
                    ? () => _addManually(voice: true)
                    : null,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.uiAddVoice),
              ),
          ],
        ),
        if (bindings.isEmpty)
          Text(
            separate
                ? l.uiNoModelsOrVoicesYetUseFetchAllOrAddManually
                : l.uiNoVoicesYetUseFetchToGetAvailableVoices,
            style: TextStyle(
              fontSize: 12,
              color: context.fg.withValues(alpha: 0.38),
            ),
          )
        else if (separate) ...[
          // Voices are not nested per model: the schema has no model→voice
          // link, so each would repeat under every TTS row.
          for (final m in tts)
            TtsProviderModelRow(
              key: ValueKey(m.id),
              model: m,
              webBlock: platform.isWeb
                  ? browserSpeechModelBlock(
                      _type.name,
                      m.modelKey,
                      baseUrl: widget.draft.baseUrl.text,
                    )
                  : null,
              voices: builtInVoicesFor(_type, m.modelKey),
              shutdownAt: retiringDescriptor(
                connection,
                m.modelKey,
              )?.shutdownAt,
              onDelete: () => _remove(m.id),
            ),
          if (custom.isNotEmpty) ...[
            const SizedBox(height: 8),
            VoiceGroupRow(
              title: l.uiCustomVoices,
              voices: custom,
              onDelete: _remove,
            ),
          ],
        ] else
          // One engine, many voices (Azure lists hundreds).
          VoiceGroupRow(
            title: l.voiceEngineVoices(_type.displayName),
            icon: Icons.mic_rounded,
            voices: [for (final v in models) (label: v.modelKey, id: v.id)],
            onDelete: _remove,
          ),
        if (separate && other.isNotEmpty) ...[
          SectionHeader(l.provOtherModels),
          for (final m in other)
            ProviderModelTile(
              key: ValueKey(m.id),
              label: m.modelKey,
              id: m.modelKey,
              source: l.provSourceFetched,
              features: modelBadges(m.modelKey, connection),
              onDelete: () => _remove(m.id),
            ),
        ],
      ],
    );
  }
}
