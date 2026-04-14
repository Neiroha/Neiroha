import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/providers/app_providers.dart';

final _selectedCharacterIdProvider = StateProvider<String?>((ref) => null);

class VoiceCharacterScreen extends ConsumerWidget {
  const VoiceCharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(voiceAssetsStreamProvider);
    final providersAsync = ref.watch(ttsProvidersStreamProvider);
    final selectedId = ref.watch(_selectedCharacterIdProvider);

    return Column(
      children: [
        _buildHeader(context, ref, providersAsync),
        const Divider(height: 1),
        Expanded(
          child: assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assets) {
              if (assets.isEmpty) return _buildEmpty(context, ref, providersAsync);
              final selected =
                  assets.where((a) => a.id == selectedId).firstOrNull;
              return ResizableSplitPane(
                initialLeftFraction: 0.6,
                left: _CharacterList(
                  assets: assets,
                  selectedId: selectedId,
                  onSelect: (id) => ref
                      .read(_selectedCharacterIdProvider.notifier)
                      .state = id,
                ),
                rightBuilder: (_) => selected != null
                    ? _CharacterInspector(asset: selected)
                    : Center(
                        child: Text('Select a character',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4)))),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref,
      AsyncValue<List<db.TtsProvider>> providersAsync) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text('Voice Characters',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('Named voice identities',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _openCreateDialog(context, ref, providersAsync),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Character'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref,
      AsyncValue<List<db.TtsProvider>> providersAsync) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('No characters yet',
              style: TextStyle(
                  fontSize: 16, color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text(
            'A Character is a named voice entity backed by a TTS provider.',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _openCreateDialog(context, ref, providersAsync),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Character'),
          ),
        ],
      ),
    );
  }

  void _openCreateDialog(BuildContext context, WidgetRef ref,
      AsyncValue<List<db.TtsProvider>> providersAsync) {
    final allProviders = providersAsync.valueOrNull ?? [];
    final enabledProviders = allProviders.where((p) => p.enabled).toList();
    if (enabledProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enable at least one Provider first (Providers tab)')));
      return;
    }
    final existingAssets = ref.read(voiceAssetsStreamProvider).valueOrNull ?? [];
    final audioTracks = ref.read(audioTracksStreamProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateCharacterDialog(
        providers: enabledProviders,
        existingAssets: existingAssets,
        audioTracks: audioTracks,
        onSave: (companion) async {
          await ref.read(databaseProvider).insertVoiceAsset(companion);
        },
        onSaveAudioTrack: (track) async {
          await ref.read(databaseProvider).insertAudioTrack(track);
        },
      ),
    );
  }
}

// ─────────────────────────── Character List ────────────────────────────────

class _CharacterList extends StatelessWidget {
  final List<db.VoiceAsset> assets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _CharacterList({
    required this.assets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final a = assets[index];
        final isSelected = a.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: isSelected
                ? AppTheme.accentColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(a.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _Avatar(name: a.name, selected: isSelected, avatarPath: a.avatarPath),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(_modeLabel(a.taskMode),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
                    ),
                    if (a.description != null && a.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.notes_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: a.enabled ? Colors.green : Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Inspector Panel ────────────────────────────────

class _CharacterInspector extends ConsumerStatefulWidget {
  final db.VoiceAsset asset;
  const _CharacterInspector({required this.asset});

  @override
  ConsumerState<_CharacterInspector> createState() =>
      _CharacterInspectorState();
}

class _CharacterInspectorState extends ConsumerState<_CharacterInspector> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final providers = ref.watch(ttsProvidersStreamProvider).valueOrNull ??
        const <db.TtsProvider>[];
    final provider = providers.where((p) => p.id == a.providerId).firstOrNull;
    final isGptSovits = provider?.adapterType == 'gptSovits';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar + change photo
        Center(
          child: GestureDetector(
            onTap: () => _pickAvatar(a),
            child: Stack(
              children: [
                _Avatar(name: a.name, selected: true, radius: 36, avatarPath: a.avatarPath),
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
        const SizedBox(height: 12),
        Center(
          child: Text(a.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Center(
          child: _ModeBadge(mode: a.taskMode),
        ),
        if (a.description != null && a.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(a.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // Fields
        if (a.modelName != null)
          _Field(isGptSovits ? 'Output Language' : 'Model', a.modelName!),
        if (a.presetVoiceName != null) _Field('Voice Name', a.presetVoiceName!),
        _Field('Speed', '${a.speed}x'),

        // Ref audio section
        if (a.refAudioPath != null) ...[
          const SizedBox(height: 4),
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton.filled(
                  onPressed: () async {
                    if (_playing) {
                      await _player.stop();
                      setState(() => _playing = false);
                    } else {
                      await _player
                          .play(DeviceFileSource(a.refAudioPath!));
                      setState(() => _playing = true);
                      _player.onPlayerComplete
                          .listen((_) => setState(() => _playing = false));
                    }
                  },
                  style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      minimumSize: const Size(36, 36)),
                  icon: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 18),
                ),
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
          if (a.promptText != null) ...[
            const SizedBox(height: 8),
            _Field('Prompt Text', a.promptText!),
          ],
          if (a.promptLang != null) _Field('Language', a.promptLang!),
        ],

        if (a.voiceInstruction != null) ...[
          const SizedBox(height: 4),
          _Field('Voice Instruction', a.voiceInstruction!),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        Row(
          children: [
            Text('Enabled',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8))),
            const Spacer(),
            Switch(
              value: a.enabled,
              onChanged: (v) {
                ref.read(databaseProvider).updateVoiceAsset(a.copyWith(enabled: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _editCharacter(a),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit Character'),
        ),
        const SizedBox(height: 8),
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
                onPressed: () {
                  ref.read(databaseProvider).deleteVoiceAsset(a.id);
                  ref.read(_selectedCharacterIdProvider.notifier).state = null;
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
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
    // Copy to app support dir so it persists
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

  void _editCharacter(db.VoiceAsset asset) {
    final allProviders = ref.read(ttsProvidersStreamProvider).valueOrNull ?? [];
    final enabledProviders = allProviders.where((p) => p.enabled).toList();
    // Include the asset's current provider even if disabled, so it's selectable
    if (!enabledProviders.any((p) => p.id == asset.providerId)) {
      final current = allProviders.where((p) => p.id == asset.providerId).firstOrNull;
      if (current != null) enabledProviders.insert(0, current);
    }
    if (enabledProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable at least one Provider first')));
      return;
    }
    final existingAssets = ref.read(voiceAssetsStreamProvider).valueOrNull ?? [];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditCharacterDialog(
        asset: asset,
        providers: enabledProviders,
        existingAssets: existingAssets,
        onSave: (updated) async {
          await ref.read(databaseProvider).updateVoiceAsset(updated);
        },
      ),
    );
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
    ref.read(_selectedCharacterIdProvider.notifier).state = newId;
  }
}

// ─────────────────────────── Create Dialog ──────────────────────────────────

class _CreateCharacterDialog extends StatefulWidget {
  final List<db.TtsProvider> providers;
  final List<db.VoiceAsset> existingAssets;
  final List<db.AudioTrack> audioTracks;
  final Future<void> Function(db.VoiceAssetsCompanion) onSave;
  final Future<void> Function(db.AudioTracksCompanion) onSaveAudioTrack;

  const _CreateCharacterDialog({
    required this.providers,
    required this.onSave,
    required this.onSaveAudioTrack,
    this.existingAssets = const [],
    this.audioTracks = const [],
  });

  @override
  State<_CreateCharacterDialog> createState() => _CreateCharacterDialogState();
}

class _CreateCharacterDialogState extends State<_CreateCharacterDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _voiceNameCtrl = TextEditingController();
  final _promptTextCtrl = TextEditingController();
  final _promptLangCtrl = TextEditingController(text: 'zh');
  final _textLangCtrl = TextEditingController(text: 'zh');
  final _instructionCtrl = TextEditingController();

  TaskMode _taskMode = TaskMode.presetVoice;
  late String _selectedProviderId;
  String? _avatarPath;
  bool _saving = false;

  final _refPlayer = AudioPlayer();
  bool _refPlaying = false;

  // Speaker list fetched from provider
  List<String> _speakers = [];
  bool _loadingSpeakers = false;
  String? _selectedSpeaker;

  // CosyVoice mode
  String? _cosyVoiceMode;

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
    _fetchSpeakers();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _voiceNameCtrl.dispose();
    _promptTextCtrl.dispose();
    _promptLangCtrl.dispose();
    _textLangCtrl.dispose();
    _instructionCtrl.dispose();
    _refPlayer.dispose();
    super.dispose();
  }

  db.TtsProvider get _selectedProvider =>
      widget.providers.firstWhere((p) => p.id == _selectedProviderId);

  String get _adapterType => _selectedProvider.adapterType;
  bool get _isCosyVoice => _adapterType == 'cosyvoice';
  bool get _isGptSovits => _adapterType == 'gptSovits';
  bool get _isPresetVoiceProvider =>
      _adapterType == 'chatCompletionsTts' ||
      _adapterType == 'openaiCompatible' ||
      _adapterType == 'azureTts' ||
      _adapterType == 'systemTts';

  Future<void> _fetchSpeakers() async {
    setState(() {
      _loadingSpeakers = true;
      _speakers = [];
      _selectedSpeaker = null;
    });
    try {
      final adapter = createAdapter(_selectedProvider);
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
  }

  /// Reusable speaker dropdown + loading indicator.
  List<Widget> _buildSpeakerPicker({String label = 'Select Speaker'}) {
    if (_loadingSpeakers) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Fetching speakers...'),
            ],
          ),
        ),
      ];
    }
    if (_speakers.isNotEmpty) {
      return [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: _speakers
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          initialValue: _selectedSpeaker,
          onChanged: (v) {
            setState(() {
              _selectedSpeaker = v;
              _voiceNameCtrl.text = v ?? '';
            });
          },
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
          player: _refPlayer,
          isPlaying: _refPlaying,
          onPick: (path) => setState(() => _uploadedRefAudioPath = path),
          onPlayToggle: (playing) =>
              setState(() => _refPlaying = playing),
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
                        _selectedAudioTrackId = null;
                        _uploadedRefAudioPath = null;
                        _voiceNameCtrl.clear();
                        _selectedSpeaker = null;
                      });
                      _fetchSpeakers();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── ADAPTER-SPECIFIC OPTIONS ──
                  if (_isPresetVoiceProvider) ...[
                    // OpenAI / Chat Completions / Azure / System TTS
                    _SectionLabel(_adapterType == 'azureTts'
                        ? 'VOICE'
                        : 'PRESET VOICE'),
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
                  ] else if (_isCosyVoice) ...[
                    // ── CosyVoice: 3 modes ──
                    _SectionLabel('COSYVOICE MODE'),
                    const SizedBox(height: 8),
                    _CosyVoiceModeSelector(
                      selected: _cosyVoiceMode,
                      onChanged: (mode) {
                        setState(() {
                          _cosyVoiceMode = mode;
                          if (mode == 'zero_shot') {
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
                      _SectionLabel('SPEAKER / PROFILE'),
                      const SizedBox(height: 8),
                      ..._buildSpeakerPicker(),
                      TextField(
                        controller: _voiceNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Profile Name',
                          hintText: 'e.g. 哆啦A梦正常',
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      if (_cosyVoiceMode == 'instruct') ...[
                        _SectionLabel('INSTRUCT'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _instructionCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Instruct Text',
                            hintText:
                                'e.g. "用轻柔的声音说话" or "speak with excitement"',
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
    // For GPT-SoVITS and CosyVoice zero_shot, ref audio is required
    if ((_isGptSovits ||
            (_isCosyVoice && _cosyVoiceMode == 'zero_shot')) &&
        refAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reference audio is required')));
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

class _RefAudioPicker extends StatelessWidget {
  final String? path;
  final AudioPlayer player;
  final bool isPlaying;
  final ValueChanged<String> onPick;
  final ValueChanged<bool> onPlayToggle;

  const _RefAudioPicker({
    required this.path,
    required this.player,
    required this.isPlaying,
    required this.onPick,
    required this.onPlayToggle,
  });

  @override
  Widget build(BuildContext context) {
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
                      if (isPlaying) {
                        await player.stop();
                        onPlayToggle(false);
                      } else {
                        await player.play(DeviceFileSource(path!));
                        onPlayToggle(true);
                        player.onPlayerComplete
                            .listen((_) => onPlayToggle(false));
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

// ─────────────────────────── Edit Character Dialog ────────────────────────────

class _EditCharacterDialog extends StatefulWidget {
  final db.VoiceAsset asset;
  final List<db.TtsProvider> providers;
  final Future<void> Function(db.VoiceAsset) onSave;
  final List<db.VoiceAsset> existingAssets;

  const _EditCharacterDialog({
    required this.asset,
    required this.providers,
    required this.onSave,
    this.existingAssets = const [],
  });

  @override
  State<_EditCharacterDialog> createState() => _EditCharacterDialogState();
}

class _EditCharacterDialogState extends State<_EditCharacterDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _voiceNameCtrl;
  late final TextEditingController _speedCtrl;
  late final TextEditingController _promptTextCtrl;
  late final TextEditingController _promptLangCtrl;
  late final TextEditingController _textLangCtrl;
  late final TextEditingController _instructionCtrl;
  late String _selectedProviderId;
  late final bool _assetWasGptSovits;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _nameCtrl = TextEditingController(text: a.name);
    _descCtrl = TextEditingController(text: a.description ?? '');
    _voiceNameCtrl = TextEditingController(text: a.presetVoiceName ?? '');
    _speedCtrl = TextEditingController(text: a.speed.toString());
    _promptTextCtrl = TextEditingController(text: a.promptText ?? '');
    _promptLangCtrl = TextEditingController(text: a.promptLang ?? '');
    _assetWasGptSovits = widget.providers
            .where((p) => p.id == a.providerId)
            .firstOrNull
            ?.adapterType ==
        'gptSovits';
    _textLangCtrl = TextEditingController(
      text: _assetWasGptSovits ? (a.modelName ?? 'zh') : 'zh',
    );
    _instructionCtrl = TextEditingController(text: a.voiceInstruction ?? '');
    _selectedProviderId = widget.providers.any((p) => p.id == a.providerId)
        ? a.providerId
        : widget.providers.first.id;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _voiceNameCtrl.dispose();
    _speedCtrl.dispose();
    _promptTextCtrl.dispose();
    _promptLangCtrl.dispose();
    _textLangCtrl.dispose();
    _instructionCtrl.dispose();
    super.dispose();
  }

  db.TtsProvider get _selectedProvider =>
      widget.providers.firstWhere((p) => p.id == _selectedProviderId);

  bool get _isSelectedGptSovits => _selectedProvider.adapterType == 'gptSovits';

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  const Text('Edit Character',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Character info at top
                  TextField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Character Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 20),
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
                                Text(
                                    '(${AdapterType.values.where((t) => t.name == p.adapterType).firstOrNull?.displayName ?? p.adapterType})',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: 0.4))),
                              ],
                            )))
                        .toList(),
                    initialValue: _selectedProviderId,
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedProviderId = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _speedCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Speed (1.0 = normal)'),
                  ),
                  const SizedBox(height: 20),
                  // Mode-specific fields
                  if (a.taskMode == 'presetVoice') ...[
                    _SectionLabel('PRESET VOICE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _voiceNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Voice / Speaker Name'),
                    ),
                  ],
                  if (a.taskMode == 'cloneWithPrompt') ...[
                    _SectionLabel('VOICE CLONE'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _promptTextCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Reference Transcript'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _promptLangCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Language Code'),
                    ),
                    if (_isSelectedGptSovits) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _textLangCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Text Language (synthesis output)',
                          hintText: 'zh / en / ja / ko ...',
                        ),
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
                      decoration: const InputDecoration(
                          labelText: 'Voice Instruction'),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
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
                    label: const Text('Save Changes'),
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
    // Uniqueness check (exclude self)
    if (widget.existingAssets
        .any((a) => a.name == name && a.id != widget.asset.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A character with this name already exists')));
      return;
    }
    setState(() => _saving = true);

    final speed = double.tryParse(_speedCtrl.text) ?? 1.0;
    final textLang = _textLangCtrl.text.trim();
    final modelName = _isSelectedGptSovits
        ? (textLang.isEmpty ? null : textLang)
        : (_assetWasGptSovits ? null : widget.asset.modelName);
    final updated = widget.asset.copyWith(
      name: name,
      description: Value(_descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim()),
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

    await widget.onSave(updated);
    if (mounted) Navigator.pop(context);
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

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis),
        ],
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
