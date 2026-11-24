import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/services/synthesis/quick_tts_service.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'editable_character_avatar.dart';
import 'character_model_field.dart';
import 'quick_tts_playback_setting.dart';
import 'character_inspector_parts.dart';
import 'voice_chain_editor.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/loudness_fields.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'character_voice_tab.dart';

// ─────────────────────────── Inspector Panel (inline editor) ────────────────

class CharacterInspector extends ConsumerStatefulWidget {
  final db.VoiceAsset asset;
  final String? bankId;

  const CharacterInspector({super.key, required this.asset, this.bankId});

  @override
  ConsumerState<CharacterInspector> createState() => _CharacterInspectorState();
}

class _CharacterInspectorState extends ConsumerState<CharacterInspector> {
  bool _saving = false;
  InspectorTab _tab = InspectorTab.basic;

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _voiceNameCtrl;
  late TextEditingController _modelNameCtrl;
  late TextEditingController _speedCtrl;
  late TextEditingController _promptTextCtrl;
  late TextEditingController _promptLangCtrl;
  late TextEditingController _textLangCtrl;
  late TextEditingController _instructionCtrl;
  late String _selectedProviderId;
  String? _selectedSpeaker;
  double _loudnessOffsetDb = 0;

  List<String> _speakers = [];
  bool _loadingSpeakers = false;

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _initControllers(widget.asset);
    _fetchSpeakers();
  }

  @override
  void didUpdateWidget(covariant CharacterInspector old) {
    super.didUpdateWidget(old);
    // Only reinitialize when switching to a different character
    if (old.asset.id != widget.asset.id) {
      _disposeControllers();
      _initControllers(widget.asset);
      _fetchSpeakers();
    }
  }

  void _initControllers(db.VoiceAsset a) {
    _nameCtrl = TextEditingController(text: a.name);
    _descCtrl = TextEditingController(text: a.description ?? '');
    _voiceNameCtrl = TextEditingController(text: a.presetVoiceName ?? '');
    _modelNameCtrl = TextEditingController(text: a.modelName ?? '');
    _speedCtrl = TextEditingController(text: a.speed.toString());
    _promptTextCtrl = TextEditingController(text: a.promptText ?? '');
    _promptLangCtrl = TextEditingController(text: a.promptLang ?? '');
    _textLangCtrl = TextEditingController(text: a.modelName ?? 'zh');
    _instructionCtrl = TextEditingController(text: a.voiceInstruction ?? '');
    _selectedProviderId = a.providerId;
    _selectedSpeaker = a.presetVoiceName;
    _loudnessOffsetDb = a.loudnessOffsetDb;
    _speakers = [];
    _loadingSpeakers = false;
  }

  void _disposeControllers() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _voiceNameCtrl.dispose();
    _modelNameCtrl.dispose();
    _speedCtrl.dispose();
    _promptTextCtrl.dispose();
    _promptLangCtrl.dispose();
    _textLangCtrl.dispose();
    _instructionCtrl.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  db.TtsProvider? get _selectedProvider {
    final providers = ref.read(ttsProvidersStreamProvider).value ?? const [];
    return providers
        .where((p) => p.id == _selectedProviderId)
        .cast<db.TtsProvider?>()
        .firstOrNull;
  }

  bool get _isPresetVoiceProvider {
    final t = _selectedProvider?.adapterType ?? '';
    return t == 'azureTts' ||
        t == 'systemTts' ||
        t == 'openaiCompatible' ||
        t == 'openaiTts' ||
        t == 'chatCompletionsTts' ||
        t == 'gptSovits' ||
        t == 'irodori' ||
        t == 'geminiTts' ||
        t == 'elevenLabs' ||
        t == 'minimaxTts';
  }

  bool get _isGptSovits => _selectedProvider?.adapterType == 'gptSovits';
  bool get _isIrodori => _selectedProvider?.adapterType == 'irodori';

  /// Adapters that store the synthesis language in modelName.
  bool get _usesTextLang =>
      _isGptSovits || _selectedProvider?.adapterType == 'indexTts';

  bool get _hasModelField {
    final t = _selectedProvider?.adapterType ?? '';
    return t == 'openaiCompatible' ||
        t == 'openaiTts' ||
        t == 'chatCompletionsTts' ||
        t == 'geminiTts' ||
        t == 'irodori' ||
        t == 'elevenLabs' ||
        t == 'minimaxTts';
  }

  Future<void> _fetchSpeakers() async {
    if (!_isPresetVoiceProvider) return;
    setState(() {
      _loadingSpeakers = true;
      _speakers = [];
    });
    final database = ref.read(databaseProvider);
    final adapterType = AdapterType.values.firstWhere(
      (t) => t.name == (_selectedProvider?.adapterType ?? ''),
      orElse: () => AdapterType.openaiCompatible,
    );
    final cached = adapterType.hasSeparateModelAndVoice
        ? await database.getVoiceEntriesForProvider(_selectedProviderId)
        : await database.getBindingsForProvider(_selectedProviderId);
    // The model's own voices first; fetched rows are account voices.
    final builtIn = builtInVoicesFor(adapterType, _modelNameCtrl.text);
    if (cached.isNotEmpty || builtIn.isNotEmpty) {
      final voices = mergeVoices(builtIn, cached.map((b) => b.modelKey));
      if (mounted) {
        setState(() {
          _speakers = voices;
          _loadingSpeakers = false;
        });
      }
      return;
    }
    final provider = _selectedProvider;
    if (provider != null) {
      try {
        final adapter = createAdapter(provider);
        final speakers = await adapter.getSpeakers();
        if (mounted) {
          setState(() {
            _speakers = speakers;
            _loadingSpeakers = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingSpeakers = false);
      }
    } else {
      if (mounted) setState(() => _loadingSpeakers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final allProviders =
        ref.watch(ttsProvidersStreamProvider).value ?? const <db.TtsProvider>[];
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final selected = _selectedProvider;
    final voices = capabilities.isWeb && selected?.adapterType == 'openaiTts'
        ? browserOpenAiVoiceOptions(
            browserSpeechModel(selected!, _modelNameCtrl.text)!,
            _speakers,
          )
        : _speakers;
    final enabledProviders = allProviders
        .where(
          (p) =>
              p.enabled &&
              speaksText(p.adapterType) &&
              capabilities.supportsAdapterName(p.adapterType),
        )
        .toList();
    // Always include the current provider even if disabled
    if (!enabledProviders.any((p) => p.id == _selectedProviderId)) {
      final current = allProviders
          .where((p) => p.id == _selectedProviderId)
          .firstOrNull;
      if (current != null) enabledProviders.insert(0, current);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Avatar ──────────────────────────────────────────────────────────
        Center(
          child: EditableCharacterAvatar(
            onEdit: kIsWeb ? null : () => _pickAvatar(a),
            avatar: VoiceCharacterAvatar(
              name: a.name,
              selected: true,
              radius: 36,
              avatarPath: a.avatarPath,
            ),
          ),
        ),
        SizedBox(height: 16),

        // ── Name ─────────────────────────────────────────────────────────────
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiCharacterName,
          ),
        ),
        SizedBox(height: 8),
        Center(child: VoiceCharacterModeBadge(mode: a.taskMode)),
        SizedBox(height: 12),
        InspectorTabs(value: _tab, onChanged: (t) => setState(() => _tab = t)),
        SizedBox(height: 16),

        if (_tab == InspectorTab.basic) ...[
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiDescriptionOptional,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                AppLocalizations.of(context).uiEnabled,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const Spacer(),
              Switch(
                value: a.enabled,
                onChanged: (v) => ref
                    .read(databaseProvider)
                    .updateVoiceAsset(a.copyWith(enabled: v)),
              ),
            ],
          ),
        ],

        // ── Voice: provider, speed, mode-specific fields ─────────────────────
        if (_tab == InspectorTab.voice)
          ..._voiceTab(
            a: a,
            allProviders: allProviders,
            enabledProviders: enabledProviders,
            selected: selected,
            voices: voices,
            capabilities: capabilities,
          ),
        if (_tab == InspectorTab.chain) VoiceChainEditor(asset: a),
        SizedBox(height: 16),
        const Divider(),
        SizedBox(height: 12),

        // ── Save ─────────────────────────────────────────────────────────────
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(AppLocalizations.of(context).uiSaveChanges),
        ),
        SizedBox(height: 8),

        CharacterActions(asset: a, bankId: widget.bankId),
      ],
    );
  }

  Future<void> _pickAvatar(db.VoiceAsset asset) async {
    final result = await pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;

    final picked = result.files.single.path!;
    final avatarDir = await PathService.instance.avatarsDir();
    final ext = p.extension(picked);
    final dest = p.join(avatarDir.path, '${asset.id}$ext');
    await File(picked).copy(dest);

    await ref
        .read(databaseProvider)
        .updateVoiceAsset(asset.copyWith(avatarPath: Value(dest)));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).uiNameIsRequired)),
      );
      return;
    }
    setState(() => _saving = true);

    final speed = double.tryParse(_speedCtrl.text) ?? 1.0;
    final a = widget.asset;
    final textLang = _textLangCtrl.text.trim();

    String? modelName;
    if (_usesTextLang) {
      modelName = textLang.isEmpty ? null : textLang;
    } else if (_hasModelField) {
      final v = _modelNameCtrl.text.trim();
      modelName = v.isEmpty ? null : v;
    } else {
      modelName = a.modelName; // preserve (e.g. cosyvoice mode)
    }

    final updated = a.copyWith(
      name: name,
      description: Value(
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      ),
      providerId: _selectedProviderId,
      modelName: Value(modelName),
      speed: speed,
      loudnessOffsetDb: _loudnessOffsetDb,
      presetVoiceName: Value(
        _voiceNameCtrl.text.trim().isEmpty ? null : _voiceNameCtrl.text.trim(),
      ),
      promptText: Value(
        _promptTextCtrl.text.trim().isEmpty
            ? null
            : _promptTextCtrl.text.trim(),
      ),
      promptLang: Value(
        _promptLangCtrl.text.trim().isEmpty
            ? null
            : _promptLangCtrl.text.trim(),
      ),
      voiceInstruction: Value(
        _instructionCtrl.text.trim().isEmpty
            ? null
            : _instructionCtrl.text.trim(),
      ),
    );

    await ref.read(databaseProvider).updateVoiceAsset(updated);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiSaved),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}

// ─────────────────────────── Create Dialog ──────────────────────────────────
