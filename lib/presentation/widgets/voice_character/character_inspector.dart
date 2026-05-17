import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/presentation/widgets/voice_character/selection.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

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

  List<String> _speakers = [];
  bool _loadingSpeakers = false;

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
    final providers =
        ref.read(ttsProvidersStreamProvider).valueOrNull ?? const [];
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
        t == 'chatCompletionsTts' ||
        t == 'gptSovits' ||
        t == 'geminiTts';
  }

  bool get _isGptSovits => _selectedProvider?.adapterType == 'gptSovits';

  bool get _hasModelField {
    final t = _selectedProvider?.adapterType ?? '';
    return t == 'openaiCompatible' ||
        t == 'chatCompletionsTts' ||
        t == 'geminiTts';
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
    if (cached.isNotEmpty) {
      final voices = cached.map((b) => b.modelKey).toList()..sort();
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
        ref.watch(ttsProvidersStreamProvider).valueOrNull ??
        const <db.TtsProvider>[];
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final enabledProviders = allProviders
        .where(
          (p) => p.enabled && capabilities.supportsAdapterName(p.adapterType),
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
          child: GestureDetector(
            onTap: () => _pickAvatar(a),
            child: Stack(
              children: [
                VoiceCharacterAvatar(
                  name: a.name,
                  selected: true,
                  radius: 36,
                  avatarPath: a.avatarPath,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBright,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surfaceDim, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
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

        // ── Description ──────────────────────────────────────────────────────
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiDescriptionOptional,
          ),
        ),
        SizedBox(height: 20),
        const Divider(),
        SizedBox(height: 12),

        // ── Provider ─────────────────────────────────────────────────────────
        VoiceCharacterSectionLabel('PROVIDER'),
        SizedBox(height: 8),
        if (enabledProviders.isEmpty)
          Text(
            AppLocalizations.of(context).uiNoProvidersAvailable,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          )
        else
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiProvider,
            ),
            initialValue:
                enabledProviders.any((p) => p.id == _selectedProviderId)
                ? _selectedProviderId
                : null,
            items: enabledProviders
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        Text(p.name),
                        SizedBox(width: 8),
                        Text(
                          '(${AdapterType.values.where((t) => t.name == p.adapterType).firstOrNull?.displayName ?? p.adapterType})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedProviderId = v;
                  _speakers = [];
                  _selectedSpeaker = null;
                });
                _fetchSpeakers();
              }
            },
          ),
        SizedBox(height: 16),

        // ── Speed ────────────────────────────────────────────────────────────
        TextField(
          controller: _speedCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiSpeed10Normal,
          ),
        ),
        SizedBox(height: 20),

        // ── Mode-specific fields ─────────────────────────────────────────────
        if (a.taskMode == 'presetVoice') ...[
          VoiceCharacterSectionLabel('VOICE'),
          SizedBox(height: 8),
          if (_loadingSpeakers)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(AppLocalizations.of(context).uiLoadingVoices),
                ],
              ),
            )
          else if (_speakers.isNotEmpty) ...[
            VoiceCharacterVoiceSearchPicker(
              label: AppLocalizations.of(context).uiSelectVoice,
              voices: _speakers,
              selected: _selectedSpeaker,
              onSelected: (v) => setState(() {
                _selectedSpeaker = v;
                _voiceNameCtrl.text = v;
              }),
            ),
            SizedBox(height: 8),
          ],
          TextField(
            controller: _voiceNameCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiVoiceName,
              helperText: AppLocalizations.of(
                context,
              ).uiFilledAutomaticallyWhenYouPickAboveOrTypeManually,
            ),
          ),
          if (_hasModelField) ...[
            SizedBox(height: 12),
            TextField(
              controller: _modelNameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiModelName,
                hintText: _selectedProvider?.adapterType == 'geminiTts'
                    ? 'e.g. gemini-2.5-flash-preview-tts'
                    : 'e.g. tts-1',
              ),
            ),
          ],
          if (_isGptSovits) ...[
            SizedBox(height: 12),
            TextField(
              controller: _textLangCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).uiTextLanguageOptional,
                hintText: AppLocalizations.of(context).uiZhEnJaKo,
              ),
            ),
          ],
          if (_selectedProvider?.adapterType == 'geminiTts') ...[
            SizedBox(height: 12),
            TextField(
              controller: _instructionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).uiStyleInstructionOptional,
                hintText: AppLocalizations.of(
                  context,
                ).uiEGSpeakSoftlyAndSlowlyPrependedToTheText,
              ),
            ),
          ],
        ],

        if (a.taskMode == 'cloneWithPrompt') ...[
          VoiceCharacterSectionLabel('VOICE CLONE'),
          SizedBox(height: 8),
          if (a.refAudioPath != null) ...[
            Text(
              AppLocalizations.of(context).uiREFERENCEAUDIO,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final playback = ref.watch(playbackNotifierProvider);
                      final isPlaying =
                          playback.audioPath == a.refAudioPath &&
                          playback.isPlaying;
                      return IconButton.filled(
                        onPressed: () async {
                          final n = ref.read(playbackNotifierProvider.notifier);
                          if (isPlaying) {
                            await n.stop();
                          } else {
                            await n.load(
                              a.refAudioPath!,
                              '${a.name} (ref)',
                              subtitle: a.name,
                            );
                          }
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          minimumSize: const Size(36, 36),
                        ),
                        icon: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.refAudioPath!.split(Platform.pathSeparator).last,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.refAudioTrimStart != null ||
                            a.refAudioTrimEnd != null)
                          Text(
                            '${a.refAudioTrimStart?.toStringAsFixed(1) ?? '0.0'}s'
                            ' → ${a.refAudioTrimEnd?.toStringAsFixed(1) ?? 'end'}s',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          TextField(
            controller: _promptTextCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiReferenceTranscript,
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _promptLangCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiLanguageCode,
            ),
          ),
          if (_isGptSovits) ...[
            SizedBox(height: 10),
            TextField(
              controller: _textLangCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).uiTextLanguageSynthesisOutput,
                hintText: AppLocalizations.of(context).uiZhEnJaKo,
              ),
            ),
          ],
          SizedBox(height: 10),
          TextField(
            controller: _instructionCtrl,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(
                context,
              ).uiStyleInstructionOptional,
            ),
          ),
        ],

        if (a.taskMode == 'voiceDesign') ...[
          VoiceCharacterSectionLabel('VOICE DESIGN'),
          SizedBox(height: 8),
          TextField(
            controller: _instructionCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).uiVoiceInstruction,
            ),
          ),
        ],

        SizedBox(height: 16),
        const Divider(),
        SizedBox(height: 12),

        // ── Enabled toggle ───────────────────────────────────────────────────
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

        // ── Duplicate / Delete ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _duplicateCharacter(a),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(AppLocalizations.of(context).uiDuplicate),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(playbackNotifierProvider.notifier)
                      .stopIfSourceTag(voiceBankQuickTestPlaybackSource);
                  try {
                    await ref.read(databaseProvider).deleteVoiceAsset(a.id);
                    ref.read(selectedCharacterIdProvider.notifier).state = null;
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(
                              context,
                            ).uiFailedToDeleteCharacter(e),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(AppLocalizations.of(context).uiDelete),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAvatar(db.VoiceAsset asset) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
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
    if (_isGptSovits) {
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

  Future<void> _duplicateCharacter(db.VoiceAsset asset) async {
    final newId = const Uuid().v4();
    final database = ref.read(databaseProvider);
    await database.insertVoiceAsset(
      db.VoiceAssetsCompanion(
        id: Value(newId),
        name: Value('${asset.name} (copy)'),
        description: Value(asset.description),
        providerId: Value(asset.providerId),
        modelBindingId: Value(asset.modelBindingId),
        modelName: Value(asset.modelName),
        taskMode: Value(asset.taskMode),
        refAudioPath: Value(asset.refAudioPath),
        refAudioTrimStart: Value(asset.refAudioTrimStart),
        refAudioTrimEnd: Value(asset.refAudioTrimEnd),
        promptText: Value(asset.promptText),
        promptLang: Value(asset.promptLang),
        voiceInstruction: Value(asset.voiceInstruction),
        presetVoiceName: Value(asset.presetVoiceName),
        avatarPath: Value(asset.avatarPath),
        speed: Value(asset.speed),
        enabled: Value(asset.enabled),
      ),
    );
    final bankId = widget.bankId;
    if (bankId != null) {
      await database.addMemberToBank(
        db.VoiceBankMembersCompanion(
          id: Value(const Uuid().v4()),
          bankId: Value(bankId),
          voiceAssetId: Value(newId),
        ),
      );
    }
    ref.read(selectedCharacterIdProvider.notifier).state = newId;
  }
}

// ─────────────────────────── Create Dialog ──────────────────────────────────
