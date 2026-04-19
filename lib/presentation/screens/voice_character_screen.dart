import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/cosyvoice_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';

/// Currently-selected character id. Shared between the merged Voice Bank
/// screen (bank-filtered character list) and [CharacterInspector] so the
/// inspector can clear the selection after delete/duplicate.
final selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

/// Opens the "Create Character" dialog. Caller can hook [onCreated] to
/// receive the new asset id — used by Voice Bank to auto-add the new
/// character as a member of the currently-selected bank.
void openCreateCharacterDialog(
  BuildContext context,
  WidgetRef ref, {
  void Function(String assetId)? onCreated,
}) {
  final allProviders =
      ref.read(ttsProvidersStreamProvider).valueOrNull ?? const [];
  final enabledProviders = allProviders.where((p) => p.enabled).toList();
  if (enabledProviders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enable at least one Provider first (Providers tab)')));
    return;
  }
  final existingAssets =
      ref.read(voiceAssetsStreamProvider).valueOrNull ?? [];
  final audioTracks =
      ref.read(audioTracksStreamProvider).valueOrNull ?? [];
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CreateCharacterDialog(
      providers: enabledProviders,
      existingAssets: existingAssets,
      audioTracks: audioTracks,
      database: ref.read(databaseProvider),
      onSave: (companion) async {
        await ref.read(databaseProvider).insertVoiceAsset(companion);
        onCreated?.call(companion.id.value);
      },
      onSaveAudioTrack: (track) async {
        await ref.read(databaseProvider).insertAudioTrack(track);
      },
    ),
  );
}

// ─────────────────────────── Inspector Panel (inline editor) ────────────────

class CharacterInspector extends ConsumerStatefulWidget {
  final db.VoiceAsset asset;
  const CharacterInspector({super.key, required this.asset});

  @override
  ConsumerState<CharacterInspector> createState() =>
      _CharacterInspectorState();
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
        t == 'chatCompletionsTts';
  }

  bool get _isGptSovits => _selectedProvider?.adapterType == 'gptSovits';

  bool get _hasModelField {
    final t = _selectedProvider?.adapterType ?? '';
    return t == 'openaiCompatible' || t == 'chatCompletionsTts';
  }

  Future<void> _fetchSpeakers() async {
    if (!_isPresetVoiceProvider) return;
    setState(() {
      _loadingSpeakers = true;
      _speakers = [];
    });
    final database = ref.read(databaseProvider);
    final cached = await database.getBindingsForProvider(_selectedProviderId);
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
        ref.watch(ttsProvidersStreamProvider).valueOrNull ?? const <db.TtsProvider>[];
    final enabledProviders = allProviders.where((p) => p.enabled).toList();
    // Always include the current provider even if disabled
    if (!enabledProviders.any((p) => p.id == _selectedProviderId)) {
      final current =
          allProviders.where((p) => p.id == _selectedProviderId).firstOrNull;
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
                _Avatar(
                    name: a.name,
                    selected: true,
                    radius: 36,
                    avatarPath: a.avatarPath),
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
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Name ─────────────────────────────────────────────────────────────
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Character Name *'),
        ),
        const SizedBox(height: 8),
        Center(child: _ModeBadge(mode: a.taskMode)),
        const SizedBox(height: 12),

        // ── Description ──────────────────────────────────────────────────────
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration:
              const InputDecoration(labelText: 'Description (optional)'),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // ── Provider ─────────────────────────────────────────────────────────
        _SectionLabel('PROVIDER'),
        const SizedBox(height: 8),
        if (enabledProviders.isEmpty)
          Text('No providers available',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.4)))
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Provider'),
            initialValue: enabledProviders.any((p) => p.id == _selectedProviderId)
                ? _selectedProviderId
                : null,
            items: enabledProviders
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Row(children: [
                        Text(p.name),
                        const SizedBox(width: 8),
                        Text(
                          '(${AdapterType.values.where((t) => t.name == p.adapterType).firstOrNull?.displayName ?? p.adapterType})',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ]),
                    ))
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
        const SizedBox(height: 16),

        // ── Speed ────────────────────────────────────────────────────────────
        TextField(
          controller: _speedCtrl,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Speed (1.0 = normal)'),
        ),
        const SizedBox(height: 20),

        // ── Mode-specific fields ─────────────────────────────────────────────
        if (a.taskMode == 'presetVoice') ...[
          _SectionLabel('VOICE'),
          const SizedBox(height: 8),
          if (_loadingSpeakers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Loading voices...'),
              ]),
            )
          else if (_speakers.isNotEmpty) ...[
            _VoiceSearchPicker(
              label: 'Select Voice',
              voices: _speakers,
              selected: _selectedSpeaker,
              onSelected: (v) => setState(() {
                _selectedSpeaker = v;
                _voiceNameCtrl.text = v;
              }),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _voiceNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Voice Name',
              helperText:
                  'Filled automatically when you pick above, or type manually',
            ),
          ),
          if (_hasModelField) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _modelNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Model Name', hintText: 'e.g. tts-1'),
            ),
          ],
        ],

        if (a.taskMode == 'cloneWithPrompt') ...[
          _SectionLabel('VOICE CLONE'),
          const SizedBox(height: 8),
          if (a.refAudioPath != null) ...[
            Text('REFERENCE AUDIO',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppTheme.surfaceDim,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Consumer(builder: (context, ref, _) {
                    final playback = ref.watch(playbackNotifierProvider);
                    final isPlaying =
                        playback.audioPath == a.refAudioPath &&
                            playback.isPlaying;
                    return IconButton.filled(
                      onPressed: () async {
                        final n =
                            ref.read(playbackNotifierProvider.notifier);
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
                          minimumSize: const Size(36, 36)),
                      icon: Icon(
                          isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 18),
                    );
                  }),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.refAudioPath!.split(Platform.pathSeparator).last,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (a.refAudioTrimStart != null ||
                            a.refAudioTrimEnd != null)
                          Text(
                            '${a.refAudioTrimStart?.toStringAsFixed(1) ?? '0.0'}s'
                            ' → ${a.refAudioTrimEnd?.toStringAsFixed(1) ?? 'end'}s',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _promptTextCtrl,
            maxLines: 3,
            decoration:
                const InputDecoration(labelText: 'Reference Transcript'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _promptLangCtrl,
            decoration: const InputDecoration(labelText: 'Language Code'),
          ),
          if (_isGptSovits) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _textLangCtrl,
              decoration: const InputDecoration(
                  labelText: 'Text Language (synthesis output)',
                  hintText: 'zh / en / ja / ko ...'),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _instructionCtrl,
            decoration: const InputDecoration(
                labelText: 'Style Instruction (optional)'),
          ),
        ],

        if (a.taskMode == 'voiceDesign') ...[
          _SectionLabel('VOICE DESIGN'),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionCtrl,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Voice Instruction'),
          ),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        // ── Enabled toggle ───────────────────────────────────────────────────
        Row(
          children: [
            Text('Enabled',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8))),
            const Spacer(),
            Switch(
              value: a.enabled,
              onChanged: (v) => ref
                  .read(databaseProvider)
                  .updateVoiceAsset(a.copyWith(enabled: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Save ─────────────────────────────────────────────────────────────
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save Changes'),
        ),
        const SizedBox(height: 8),

        // ── Duplicate / Delete ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _duplicateCharacter(a),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Duplicate'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(playbackNotifierProvider.notifier)
                      .stopIfSourceTag(voiceBankQuickTestPlaybackSource);
                  await ref.read(databaseProvider).deleteVoiceAsset(a.id);
                  ref
                      .read(selectedCharacterIdProvider.notifier)
                      .state = null;
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent),
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
    final appDir = await getApplicationSupportDirectory();
    final avatarDir = Directory(p.join(appDir.path, 'avatars'));
    if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final existingAssets =
        ref.read(voiceAssetsStreamProvider).valueOrNull ?? [];
    if (existingAssets
        .any((x) => x.name == name && x.id != widget.asset.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A character with this name already exists')));
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
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()),
      providerId: _selectedProviderId,
      modelName: Value(modelName),
      speed: speed,
      presetVoiceName: Value(_voiceNameCtrl.text.trim().isEmpty
          ? null
          : _voiceNameCtrl.text.trim()),
      promptText: Value(_promptTextCtrl.text.trim().isEmpty
          ? null
          : _promptTextCtrl.text.trim()),
      promptLang: Value(_promptLangCtrl.text.trim().isEmpty
          ? null
          : _promptLangCtrl.text.trim()),
      voiceInstruction: Value(_instructionCtrl.text.trim().isEmpty
          ? null
          : _instructionCtrl.text.trim()),
    );

    await ref.read(databaseProvider).updateVoiceAsset(updated);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved'), duration: Duration(seconds: 1)));
    }
  }

  Future<void> _duplicateCharacter(db.VoiceAsset asset) async {
    final newId = const Uuid().v4();
    await ref.read(databaseProvider).insertVoiceAsset(db.VoiceAssetsCompanion(
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
        ));
    ref.read(selectedCharacterIdProvider.notifier).state = newId;
  }
}

// ─────────────────────────── Create Dialog ──────────────────────────────────

class CreateCharacterDialog extends StatefulWidget {
  final List<db.TtsProvider> providers;
  final List<db.VoiceAsset> existingAssets;
  final List<db.AudioTrack> audioTracks;
  final Future<void> Function(db.VoiceAssetsCompanion) onSave;
  final Future<void> Function(db.AudioTracksCompanion) onSaveAudioTrack;
  final db.AppDatabase database;

  const CreateCharacterDialog({
    super.key,
    required this.providers,
    required this.onSave,
    required this.onSaveAudioTrack,
    required this.database,
    this.existingAssets = const [],
    this.audioTracks = const [],
  });

  @override
  State<CreateCharacterDialog> createState() => _CreateCharacterDialogState();
}

class _CreateCharacterDialogState extends State<CreateCharacterDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _voiceNameCtrl = TextEditingController();
  final _modelNameCtrl = TextEditingController();
  final _promptTextCtrl = TextEditingController();
  final _promptLangCtrl = TextEditingController(text: 'zh');
  final _textLangCtrl = TextEditingController(text: 'zh');
  final _instructionCtrl = TextEditingController();

  TaskMode _taskMode = TaskMode.presetVoice;
  late String _selectedProviderId;
  String? _avatarPath;
  bool _saving = false;


  // Voice list fetched/cached from provider
  List<String> _speakers = [];
  bool _loadingSpeakers = false;
  String? _selectedSpeaker;

  // Model list (only for hasSeparateModelAndVoice adapters)
  List<String> _models = [];
  bool _loadingModels = false;
  String? _selectedModel;

  // CosyVoice mode
  String? _cosyVoiceMode;

  // CosyVoice server-side profiles (from `/cosyvoice/profiles`). These are the
  // ONLY values that can safely be sent as `profile` — typing a name that
  // doesn't exist on the server makes `build_runtime_char_config` reject the
  // request with 400 "未找到角色".
  List<CosyVoiceProfile> _cosyProfiles = [];
  bool _loadingCosyProfiles = false;
  String? _selectedCosyProfileId;

  // VoxCPM2 mode: 'design' | 'clone' | 'ultimate_clone'.
  String? _voxcpmMode;

  // VoxCPM2 registered voices (from `/voxcpm/voices`). Used as `voice_id`
  // in clone mode — only server-registered ids are accepted.
  List<VoxCpm2Voice> _voxcpmVoices = [];
  bool _loadingVoxcpmVoices = false;
  String? _selectedVoxcpmVoiceId;

  // Reference audio: from voice assets OR manual upload
  String? _selectedAudioTrackId;
  String? _uploadedRefAudioPath;

  String? get _effectiveRefAudioPath {
    if (_selectedAudioTrackId != null) {
      final track = widget.audioTracks
          .where((t) => t.id == _selectedAudioTrackId)
          .firstOrNull;
      return track?.audioPath;
    }
    return _uploadedRefAudioPath;
  }

  @override
  void initState() {
    super.initState();
    _selectedProviderId = widget.providers.first.id;
    _fetchModelsAndSpeakers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _voiceNameCtrl.dispose();
    _modelNameCtrl.dispose();
    _promptTextCtrl.dispose();
    _promptLangCtrl.dispose();
    _textLangCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
  }

  db.TtsProvider get _selectedProvider =>
      widget.providers.firstWhere((p) => p.id == _selectedProviderId);

  String get _adapterType => _selectedProvider.adapterType;
  bool get _isCosyVoice => _adapterType == 'cosyvoice';
  bool get _isVoxCpm2 => _adapterType == 'voxcpm2Native';
  bool get _isGptSovits => _adapterType == 'gptSovits';
  bool get _isPresetVoiceProvider =>
      _adapterType == 'chatCompletionsTts' ||
      _adapterType == 'openaiCompatible' ||
      _adapterType == 'azureTts' ||
      _adapterType == 'systemTts';

  Future<void> _fetchModelsAndSpeakers() async {
    setState(() {
      _loadingSpeakers = true;
      _loadingModels = true;
      _speakers = [];
      _models = [];
      _selectedSpeaker = null;
      _selectedModel = null;
      _modelNameCtrl.clear();
      _voiceNameCtrl.clear();
    });

    final adapterType = _selectedProvider.adapterType;
    final hasSeparate = AdapterType.values
        .firstWhere((t) => t.name == adapterType,
            orElse: () => AdapterType.openaiCompatible)
        .hasSeparateModelAndVoice;

    if (hasSeparate) {
      // Models from cache
      final cachedModels =
          await widget.database.getModelEntriesForProvider(_selectedProviderId);
      final modelList = cachedModels.map((b) => b.modelKey).toList()..sort();

      // Voices from cache
      final cachedVoices =
          await widget.database.getVoiceEntriesForProvider(_selectedProviderId);
      final voiceList = cachedVoices.map((b) => b.modelKey).toList()..sort();

      if (mounted) {
        setState(() {
          _models = modelList;
          _speakers = voiceList;
          _loadingModels = false;
          _loadingSpeakers = false;
          // Auto-select model if only one
          if (modelList.length == 1) {
            _selectedModel = modelList.first;
            _modelNameCtrl.text = modelList.first;
          }
        });
      }
    } else {
      // CosyVoice native exposes profiles via /cosyvoice/profiles — fetch them
      // so the user can pick a registered one instead of typing a name that
      // the server will reject.
      if (_isCosyVoice) {
        if (mounted) setState(() { _loadingSpeakers = false; _loadingModels = false; });
        _fetchCosyVoiceProfiles();
        return;
      }
      // VoxCPM2 native exposes registered voices via /voxcpm/voices — same
      // rationale: clone mode's `voice_id` must match a registered id.
      if (_isVoxCpm2) {
        if (mounted) setState(() { _loadingSpeakers = false; _loadingModels = false; });
        _fetchVoxCpm2Voices();
        return;
      }
      // Voice-only providers (Azure, System TTS, GPT-SoVITS)
      final cached =
          await widget.database.getBindingsForProvider(_selectedProviderId);
      if (cached.isNotEmpty) {
        final voices = cached.map((b) => b.modelKey).toList()..sort();
        if (mounted) {
          setState(() {
            _speakers = voices;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        return;
      }
      // No cache — live API fetch fallback
      try {
        final adapter = createAdapter(_selectedProvider);
        final speakers = await adapter.getSpeakers();
        if (mounted) {
          setState(() {
            _speakers = speakers;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
      }
    }
  }

  /// Live-fetch CosyVoice native profiles from `/cosyvoice/profiles`.
  Future<void> _fetchCosyVoiceProfiles() async {
    if (!_isCosyVoice) return;
    setState(() {
      _loadingCosyProfiles = true;
      _cosyProfiles = [];
      _selectedCosyProfileId = null;
    });
    try {
      final adapter = createAdapter(_selectedProvider);
      if (adapter is CosyVoiceAdapter) {
        final profiles = await adapter.getProfiles();
        if (mounted) {
          setState(() {
            _cosyProfiles = profiles;
            _loadingCosyProfiles = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCosyProfiles = false);
  }

  /// Live-fetch VoxCPM2 registered voices from `/voxcpm/voices`.
  Future<void> _fetchVoxCpm2Voices() async {
    if (!_isVoxCpm2) return;
    setState(() {
      _loadingVoxcpmVoices = true;
      _voxcpmVoices = [];
      _selectedVoxcpmVoiceId = null;
    });
    try {
      final adapter = createAdapter(_selectedProvider);
      if (adapter is VoxCpm2NativeAdapter) {
        final voices = await adapter.getVoices();
        if (mounted) {
          setState(() {
            _voxcpmVoices = voices;
            _loadingVoxcpmVoices = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingVoxcpmVoices = false);
  }

  /// Reusable searchable speaker picker + loading indicator.
  List<Widget> _buildSpeakerPicker({String label = 'Select Voice'}) {
    if (_loadingSpeakers) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading voices...'),
            ],
          ),
        ),
      ];
    }
    if (_speakers.isNotEmpty) {
      return [
        _VoiceSearchPicker(
          label: label,
          voices: _speakers,
          selected: _selectedSpeaker,
          onSelected: (v) => setState(() {
            _selectedSpeaker = v;
            _voiceNameCtrl.text = v;
          }),
        ),
        const SizedBox(height: 8),
      ];
    }
    return [];
  }

  /// Build the reference audio picker with voice asset library support.
  List<Widget> _buildRefAudioPicker() {
    return [
      _SectionLabel('REFERENCE AUDIO'),
      const SizedBox(height: 8),
      // Pick from voice assets library
      if (widget.audioTracks.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Select from Voice Assets',
            prefixIcon: Icon(Icons.library_music_rounded, size: 18),
          ),
          isExpanded: true,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('None (upload manually)',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ),
            ...widget.audioTracks.map((t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(t.name, overflow: TextOverflow.ellipsis),
                )),
          ],
          initialValue: _selectedAudioTrackId,
          onChanged: (v) {
            setState(() {
              _selectedAudioTrackId = v;
              if (v != null) {
                _uploadedRefAudioPath = null;
                // Auto-fill prompt text/lang from track metadata
                final track = widget.audioTracks
                    .where((t) => t.id == v)
                    .firstOrNull;
                if (track != null) {
                  if (track.refText != null &&
                      track.refText!.isNotEmpty &&
                      _promptTextCtrl.text.isEmpty) {
                    _promptTextCtrl.text = track.refText!;
                  }
                  if (track.refLang != null &&
                      track.refLang!.isNotEmpty &&
                      _promptLangCtrl.text == 'zh') {
                    _promptLangCtrl.text = track.refLang!;
                  }
                }
              }
            });
          },
        ),
        const SizedBox(height: 10),
        if (_selectedAudioTrackId == null) ...[
          Text('— or upload a new file —',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(height: 8),
        ],
      ],
      // Manual upload (shown when no track selected or no tracks exist)
      if (_selectedAudioTrackId == null)
        _RefAudioPicker(
          path: _uploadedRefAudioPath,
          onPick: (path) => setState(() => _uploadedRefAudioPath = path),
        ),
      const SizedBox(height: 12),
    ];
  }

  Future<void> _pickAvatarForCreate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _avatarPath = result.files.single.path!);
  }

  void _autoFillName() {
    final providerName = _selectedProvider.name;
    final speaker = _voiceNameCtrl.text.trim().isNotEmpty
        ? _voiceNameCtrl.text.trim()
        : (_selectedSpeaker ?? 'voice');
    _nameCtrl.text = '${providerName}_$speaker';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 560,
        height: 720,
        child: Column(
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  const Text('New Voice Character',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Scrollable body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // ── CHARACTER INFO (at top) ──
                  _SectionLabel('CHARACTER INFO'),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatarForCreate,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor:
                                AppTheme.accentColor.withValues(alpha: 0.15),
                            backgroundImage: _avatarPath != null
                                ? FileImage(File(_avatarPath!))
                                : null,
                            child: _avatarPath == null
                                ? Icon(Icons.person_rounded,
                                    size: 36,
                                    color:
                                        Colors.white.withValues(alpha: 0.3))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBright,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.surfaceDim, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Character Name *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Auto-fill: Provider + Speaker',
                        child: IconButton(
                          onPressed: _autoFillName,
                          icon: const Icon(Icons.auto_fix_high_rounded,
                              size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 20),

                  // ── PROVIDER ──
                  _SectionLabel('PROVIDER'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(labelText: 'Provider'),
                    items: widget.providers
                        .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Row(
                              children: [
                                Text(p.name),
                                const SizedBox(width: 8),
                                Text('(${AdapterType.values.where((t) => t.name == p.adapterType).firstOrNull?.displayName ?? p.adapterType})',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.4))),
                              ],
                            )))
                        .toList(),
                    initialValue: _selectedProviderId,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedProviderId = v;
                        _cosyVoiceMode = null;
                        _voxcpmMode = null;
                        _selectedVoxcpmVoiceId = null;
                        _selectedAudioTrackId = null;
                        _uploadedRefAudioPath = null;
                        _voiceNameCtrl.clear();
                        _selectedSpeaker = null;
                      });
                      _fetchModelsAndSpeakers();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── ADAPTER-SPECIFIC OPTIONS ──
                  if (_isPresetVoiceProvider) ...[
                    if (_adapterType == 'openaiCompatible' ||
                        _adapterType == 'chatCompletionsTts') ...[
                      // ── OpenAI-compatible: separate Model + Voice ──
                      _SectionLabel('MODEL'),
                      const SizedBox(height: 8),
                      if (_loadingModels)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Loading models...'),
                          ]),
                        )
                      else if (_models.isNotEmpty) ...[
                        _VoiceSearchPicker(
                          label: 'Select Model',
                          voices: _models,
                          selected: _selectedModel,
                          onSelected: (v) => setState(() {
                            _selectedModel = v;
                            _modelNameCtrl.text = v;
                          }),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: _modelNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Model Name',
                          hintText: 'e.g. tts-1',
                          helperText: _models.isEmpty
                              ? 'Go to Providers → Fetch to cache available models'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionLabel('VOICE'),
                      const SizedBox(height: 8),
                      ..._buildSpeakerPicker(label: 'Select Voice'),
                      TextField(
                        controller: _voiceNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Voice Name',
                          hintText: 'e.g. alloy',
                          helperText: _speakers.isEmpty
                              ? 'Go to Providers → Fetch to cache available voices'
                              : null,
                        ),
                      ),
                    ] else ...[
                      // ── Azure / System TTS: voices only ──
                      _SectionLabel(
                          _adapterType == 'azureTts' ? 'VOICE' : 'PRESET VOICE'),
                      const SizedBox(height: 8),
                      ..._buildSpeakerPicker(
                        label: _adapterType == 'azureTts'
                            ? 'Select Voice'
                            : 'Select Speaker',
                      ),
                      TextField(
                        controller: _voiceNameCtrl,
                        decoration: InputDecoration(
                          labelText: _adapterType == 'azureTts'
                              ? 'Voice Name'
                              : 'Voice / Speaker Name',
                          hintText: _adapterType == 'azureTts'
                              ? 'e.g. en-US-AriaNeural'
                              : 'e.g. alloy, mimo_default',
                        ),
                      ),
                    ],
                  ] else if (_isCosyVoice) ...[
                    // ── CosyVoice: 3 modes ──
                    _SectionLabel('COSYVOICE MODE'),
                    const SizedBox(height: 8),
                    _CosyVoiceModeSelector(
                      selected: _cosyVoiceMode,
                      onChanged: (mode) {
                        setState(() {
                          _cosyVoiceMode = mode;
                          // cross_lingual also clones from reference audio
                          if (mode == 'zero_shot' || mode == 'cross_lingual') {
                            _taskMode = TaskMode.cloneWithPrompt;
                          } else if (mode == 'instruct') {
                            _taskMode = TaskMode.voiceDesign;
                          } else {
                            _taskMode = TaskMode.presetVoice;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_cosyVoiceMode != null) ...[
                      _SectionLabel('SERVER PROFILE (optional)'),
                      const SizedBox(height: 4),
                      Text(
                        'A profile registered on the CosyVoice server. '
                        'Leave as "None" to synthesise purely from your uploaded '
                        'reference audio — typing a name that the server '
                        'doesn\'t know causes 400 "未找到角色".',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingCosyProfiles)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Loading server profiles...'),
                          ]),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(
                            labelText: 'Server Profile',
                            prefixIcon:
                                Icon(Icons.folder_shared_rounded, size: 18),
                          ),
                          isExpanded: true,
                          initialValue: _selectedCosyProfileId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None (use uploaded audio only)',
                                  style:
                                      TextStyle(fontStyle: FontStyle.italic)),
                            ),
                            ..._cosyProfiles.map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(
                                    p.modeLabel.isNotEmpty
                                        ? '${p.name}  ·  ${p.modeLabel}'
                                        : p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedCosyProfileId = v;
                            _voiceNameCtrl.text = v ?? '';
                          }),
                        ),
                      const SizedBox(height: 12),

                      // ── Zero Shot ──────────────────────────────────────────
                      if (_cosyVoiceMode == 'zero_shot') ...[
                        ..._buildRefAudioPicker(),
                        TextField(
                          controller: _promptTextCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Prompt Text (spoken in ref audio)',
                            hintText: 'Transcript of the reference audio',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _promptLangCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Language Code',
                            hintText: 'zh / en / ja / ko ...',
                          ),
                        ),
                      ],

                      // ── Cross Lingual ──────────────────────────────────────
                      if (_cosyVoiceMode == 'cross_lingual') ...[
                        _SectionLabel('REFERENCE AUDIO'),
                        const SizedBox(height: 4),
                        Text(
                          'Upload a voice sample — the model will clone its tone and speak the synthesis text in any language.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 8),
                        ..._buildRefAudioPicker(),
                      ],

                      // ── Instruct ───────────────────────────────────────────
                      if (_cosyVoiceMode == 'instruct') ...[
                        _SectionLabel('INSTRUCT'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _instructionCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Instruct Text *',
                            hintText:
                                'e.g. "用轻柔的声音说话" or "speak with excitement"',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SectionLabel('REFERENCE AUDIO (optional)'),
                        const SizedBox(height: 4),
                        Text(
                          'Upload a voice sample to use as the base voice instead of a preset profile.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 8),
                        ..._buildRefAudioPicker(),
                      ],
                    ],
                  ] else if (_isVoxCpm2) ...[
                    // ── VoxCPM2 Native: 3 modes ──
                    _SectionLabel('VOXCPM2 MODE'),
                    const SizedBox(height: 8),
                    _VoxCpm2ModeSelector(
                      selected: _voxcpmMode,
                      onChanged: (mode) {
                        setState(() {
                          _voxcpmMode = mode;
                          // design: text-only → voiceDesign task mode.
                          // clone / ultimate_clone: require audio → cloneWithPrompt.
                          if (mode == 'design') {
                            _taskMode = TaskMode.voiceDesign;
                          } else {
                            _taskMode = TaskMode.cloneWithPrompt;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_voxcpmMode != null) ...[
                      // Registered voice picker (optional — only meaningful in
                      // clone / ultimate_clone; for design we still show it
                      // disabled-via-empty-list so the UI is consistent).
                      if (_voxcpmMode != 'design') ...[
                        _SectionLabel('REGISTERED VOICE (optional)'),
                        const SizedBox(height: 4),
                        Text(
                          'A voice profile registered on the server. Leave '
                          'as "None" to synthesise purely from your uploaded '
                          'reference audio — sending an unregistered id is '
                          'rejected.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingVoxcpmVoices)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Loading registered voices...'),
                            ]),
                          )
                        else
                          DropdownButtonFormField<String?>(
                            decoration: const InputDecoration(
                              labelText: 'Registered Voice',
                              prefixIcon:
                                  Icon(Icons.folder_shared_rounded, size: 18),
                            ),
                            isExpanded: true,
                            initialValue: _selectedVoxcpmVoiceId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None (use uploaded audio only)',
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic)),
                              ),
                              ..._voxcpmVoices
                                  .map((v) => DropdownMenuItem<String?>(
                                        value: v.id,
                                        child: Text(
                                          v.displayName.isNotEmpty
                                              ? '${v.displayName}  ·  ${v.id}'
                                              : v.id,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedVoxcpmVoiceId = v;
                              _voiceNameCtrl.text = v ?? '';
                            }),
                          ),
                        const SizedBox(height: 12),
                      ],

                      // ── Design ─────────────────────────────────────────────
                      if (_voxcpmMode == 'design') ...[
                        _SectionLabel('VOICE DESCRIPTION'),
                        const SizedBox(height: 4),
                        Text(
                          'Natural-language voice description. At synthesis '
                          'time, prepend it to the text in parentheses — e.g.\n'
                          '(A young woman, gentle and sweet voice)',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _instructionCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Voice Description *',
                            hintText:
                                'A young woman, gentle and sweet voice',
                          ),
                        ),
                      ],

                      // ── Clone ──────────────────────────────────────────────
                      if (_voxcpmMode == 'clone') ...[
                        ..._buildRefAudioPicker(),
                      ],

                      // ── Ultimate Clone ─────────────────────────────────────
                      if (_voxcpmMode == 'ultimate_clone') ...[
                        ..._buildRefAudioPicker(),
                        TextField(
                          controller: _promptTextCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Prompt Text (spoken in ref audio) *',
                            hintText: 'Transcript of the reference audio',
                          ),
                        ),
                      ],
                    ],
                  ] else if (_isGptSovits) ...[
                    // ── GPT-SoVITS: always ref audio mode ──
                    ..._buildRefAudioPicker(),
                    TextField(
                      controller: _promptTextCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Prompt Text (spoken in ref audio)',
                        hintText: 'Transcript of the reference audio',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _promptLangCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prompt Language',
                        hintText: 'zh / en / ja / ko ...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _textLangCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Text Language (synthesis output)',
                        hintText: 'zh / en / ja / ko ...',
                      ),
                    ),
                  ] else ...[
                    // ── Fallback for other adapters (qwen3, etc.) ──
                    _SectionLabel('VOICE'),
                    const SizedBox(height: 8),
                    ..._buildSpeakerPicker(),
                    TextField(
                      controller: _voiceNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Voice / Speaker Name',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Create Character'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    if (widget.existingAssets.any((a) => a.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A character with this name already exists')));
      return;
    }

    final refAudio = _effectiveRefAudioPath;
    // GPT-SoVITS and CosyVoice zero_shot / cross_lingual require ref audio.
    // cross_lingual can skip it only if a profile name is given instead.
    // VoxCPM2 clone / ultimate_clone need ref audio unless a registered
    // voice_id is chosen.
    final voxcpmNeedsAudio = _isVoxCpm2 &&
        (_voxcpmMode == 'clone' || _voxcpmMode == 'ultimate_clone') &&
        _voiceNameCtrl.text.trim().isEmpty;
    final needsRefAudio = _isGptSovits ||
        (_isCosyVoice && _cosyVoiceMode == 'zero_shot') ||
        (_isCosyVoice &&
            _cosyVoiceMode == 'cross_lingual' &&
            _voiceNameCtrl.text.trim().isEmpty) ||
        voxcpmNeedsAudio;
    if (needsRefAudio && refAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isCosyVoice && _cosyVoiceMode == 'cross_lingual'
              ? 'Cross Lingual mode requires a Reference Audio or a Profile Name'
              : _isVoxCpm2
                  ? 'VoxCPM2 ${_voxcpmMode == 'ultimate_clone' ? 'Ultra Clone' : 'Clone'} needs a Reference Audio or a Registered Voice'
                  : 'Reference audio is required')));
      return;
    }
    if (_isVoxCpm2 && _voxcpmMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a VoxCPM2 mode')));
      return;
    }
    if (_isVoxCpm2 &&
        _voxcpmMode == 'design' &&
        _instructionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Design mode requires a Voice Description')));
      return;
    }
    if (_isVoxCpm2 &&
        _voxcpmMode == 'ultimate_clone' &&
        _promptTextCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ultra Clone mode requires a Prompt Text')));
      return;
    }

    setState(() => _saving = true);

    // Determine task mode
    TaskMode effectiveMode;
    if (_isPresetVoiceProvider) {
      effectiveMode = TaskMode.presetVoice;
    } else if (_isGptSovits) {
      effectiveMode = TaskMode.cloneWithPrompt;
    } else {
      effectiveMode = _taskMode;
    }

    final assetId = const Uuid().v4();

    // Copy avatar to persistent location if picked
    String? persistedAvatarPath;
    if (_avatarPath != null) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(appDir.path, 'avatars'));
        if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
        final ext = p.extension(_avatarPath!);
        final dest = p.join(avatarDir.path, '$assetId$ext');
        await File(_avatarPath!).copy(dest);
        persistedAvatarPath = dest;
      } catch (_) {}
    }

    // Auto-save manually uploaded ref audio to voice assets library
    if (_uploadedRefAudioPath != null && _selectedAudioTrackId == null) {
      try {
        final appDir = await getApplicationSupportDirectory();
        final vaDir =
            Directory(p.join(appDir.path, 'voice_assets'));
        if (!vaDir.existsSync()) vaDir.createSync(recursive: true);
        final trackId = const Uuid().v4();
        final ext = p.extension(_uploadedRefAudioPath!);
        final dest = p.join(vaDir.path, '$trackId$ext');
        await File(_uploadedRefAudioPath!).copy(dest);
        await widget.onSaveAudioTrack(db.AudioTracksCompanion(
          id: Value(trackId),
          name: Value(p.basenameWithoutExtension(_uploadedRefAudioPath!)),
          audioPath: Value(dest),
          refText: Value(_promptTextCtrl.text.trim().isEmpty
              ? null
              : _promptTextCtrl.text.trim()),
          refLang: Value(_promptLangCtrl.text.trim().isEmpty
              ? null
              : _promptLangCtrl.text.trim()),
          sourceType: const Value('upload'),
          createdAt: Value(DateTime.now()),
        ));
      } catch (_) {}
    }

    await widget.onSave(db.VoiceAssetsCompanion(
      id: Value(assetId),
      name: Value(name),
      description: Value(_descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim()),
      providerId: Value(_selectedProviderId),
      modelBindingId: const Value(null),
      modelName: Value(_isGptSovits
          ? (_textLangCtrl.text.trim().isEmpty
              ? null
              : _textLangCtrl.text.trim())
          : (_adapterType == 'openaiCompatible' ||
                  _adapterType == 'chatCompletionsTts')
              ? (_modelNameCtrl.text.trim().isEmpty
                  ? null
                  : _modelNameCtrl.text.trim())
              // CosyVoice native: store the synthesis mode so the adapter
              // can route zero_shot / cross_lingual / instruct correctly.
              : _isCosyVoice
                  ? _cosyVoiceMode
                  // VoxCPM2 native: same pattern — store design / clone /
                  // ultimate_clone so the adapter routes requests correctly.
                  : _isVoxCpm2
                      ? _voxcpmMode
                      : null),
      taskMode: Value(effectiveMode.name),
      refAudioPath: Value(refAudio),
      refAudioTrimStart: const Value(null),
      refAudioTrimEnd: const Value(null),
      promptText: Value(_promptTextCtrl.text.trim().isEmpty
          ? null
          : _promptTextCtrl.text.trim()),
      promptLang: Value(_promptLangCtrl.text.trim().isEmpty
          ? null
          : _promptLangCtrl.text.trim()),
      voiceInstruction: Value(_instructionCtrl.text.trim().isEmpty
          ? null
          : _instructionCtrl.text.trim()),
      presetVoiceName: Value(_voiceNameCtrl.text.trim().isEmpty
          ? null
          : _voiceNameCtrl.text.trim()),
      avatarPath: Value(persistedAvatarPath),
    ));

    if (mounted) Navigator.pop(context);
  }
}

// ─────────────────────────── Sub-widgets ────────────────────────────────────

class _VoxCpm2ModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const _VoxCpm2ModeSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    ('design', Icons.text_fields_rounded, 'Design',
        'Describe the voice\nin natural language'),
    ('clone', Icons.mic_rounded, 'Clone',
        'Clone voice from\nreference audio'),
    ('ultimate_clone', Icons.auto_awesome_rounded, 'Ultra Clone',
        'Clone with prompt\ntranscript + audio'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode != 'ultimate_clone' ? 8 : 0),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceDim,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CosyVoiceModeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const _CosyVoiceModeSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    ('zero_shot', Icons.mic_rounded, 'Zero Shot',
        'Clone voice from\nreference audio'),
    ('cross_lingual', Icons.translate_rounded, 'Cross Lingual',
        'Cross-language\nvoice synthesis'),
    ('instruct', Icons.text_fields_rounded, 'Instruct',
        'Control voice via\ntext instructions'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((rec) {
        final (mode, icon, label, hint) = rec;
        final isSelected = selected == mode;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode != 'instruct' ? 8 : 0),
            child: InkWell(
              onTap: () => onChanged(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppTheme.accentColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceDim,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RefAudioPicker extends ConsumerWidget {
  final String? path;
  final ValueChanged<String> onPick;

  const _RefAudioPicker({
    required this.path,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackNotifierProvider);
    final isPlaying = path != null &&
        playback.audioPath == path &&
        playback.isPlaying;
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDim,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: path != null
                ? Colors.green.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: path == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_rounded,
                      color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 10),
                  Text('Click to select audio file',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4))),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.audio_file_rounded, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path!.split(Platform.pathSeparator).last,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Tap to change',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    Colors.white.withValues(alpha: 0.3))),
                      ],
                    ),
                  ),
                  // Play / stop preview
                  IconButton(
                    onPressed: () async {
                      final n =
                          ref.read(playbackNotifierProvider.notifier);
                      if (isPlaying) {
                        await n.stop();
                      } else {
                        await n.load(
                          path!,
                          path!.split(Platform.pathSeparator).last,
                        );
                      }
                    },
                    icon: Icon(isPlaying
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded),
                    tooltip: isPlaying ? 'Stop' : 'Preview',
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      onPick(result.files.single.path!);
    }
  }
}

// ─────────────────────────── Shared helpers ─────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final bool selected;
  final double radius;
  final String? avatarPath;
  const _Avatar({
    required this.name,
    required this.selected,
    this.radius = 20,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && File(avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          selected ? AppTheme.accentColor : const Color(0xFF2A2A36),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.75, color: Colors.white),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _modeLabel(mode),
        style: TextStyle(fontSize: 12, color: AppTheme.accentColor),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4)),
      );
}

String _modeLabel(String mode) => switch (mode) {
      'cloneWithPrompt' => 'Voice Clone',
      'presetVoice' => 'Preset Voice',
      'voiceDesign' => 'Voice Design',
      _ => mode,
    };

// ─────────────────────────── Voice Search Picker ────────────────────────────

/// A searchable voice list that replaces the standard DropdownButtonFormField
/// for providers with large voice libraries (e.g. Azure ~400 voices).
///
/// Shows a search TextField and a scrollable filtered list below it.
/// Selecting an item calls [onSelected] and highlights the row.
class _VoiceSearchPicker extends StatefulWidget {
  final String label;
  final List<String> voices;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _VoiceSearchPicker({
    required this.label,
    required this.voices,
    required this.onSelected,
    this.selected,
  });

  @override
  State<_VoiceSearchPicker> createState() => _VoiceSearchPickerState();
}

class _VoiceSearchPickerState extends State<_VoiceSearchPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.voices;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(covariant _VoiceSearchPicker old) {
    super.didUpdateWidget(old);
    if (old.voices != widget.voices) {
      _filtered = _applyFilter(_searchCtrl.text);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() => setState(() => _filtered = _applyFilter(_searchCtrl.text));

  List<String> _applyFilter(String query) {
    if (query.isEmpty) return widget.voices;
    final q = query.toLowerCase();
    return widget.voices.where((v) => v.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search field
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Search voices… (${widget.voices.length} total)',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () => _searchCtrl.clear(),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        // Filtered list in a bounded container
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.surfaceDim,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'No voices match "${_searchCtrl.text}"',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final voice = _filtered[i];
                    final isSelected = voice == widget.selected;
                    return InkWell(
                      onTap: () => widget.onSelected(voice),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        color: isSelected
                            ? AppTheme.accentColor.withValues(alpha: 0.18)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.check_rounded,
                                    size: 14,
                                    color: AppTheme.accentColor),
                              ),
                            Expanded(
                              child: Text(
                                voice,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected
                                      ? AppTheme.accentColor
                                      : Colors.white.withValues(alpha: 0.85),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
