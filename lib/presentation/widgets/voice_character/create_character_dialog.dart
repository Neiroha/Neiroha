import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/adapters/cosyvoice_adapter.dart';
import 'package:neiroha/data/adapters/chat_completions_tts_adapter.dart';
import 'package:neiroha/data/adapters/tts_adapter.dart';
import 'package:neiroha/data/adapters/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

class CreateCharacterDialog extends StatefulWidget {
  final List<db.TtsProvider> providers;
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

  // TTS model type: 'preset' | 'clone' | 'design' — determined by model name
  String? _ttsModelType;

  // CosyVoice mode
  String? _cosyVoiceMode;

  // GPT-SoVITS mode: 'trained' uses saved server speaker profiles; 'clone'
  // uses reference audio and matching prompt text.
  String _gptSovitsMode = 'trained';

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
      _adapterType == 'systemTts' ||
      _adapterType == 'geminiTts';
  bool get _isGeminiTts => _adapterType == 'geminiTts';

  /// Whether a model key is a TTS model (not LLM/multimodal).
  /// Used to filter the model picker in the voice character dialog.
  static bool _isTtsModel(String modelKey) {
    final k = modelKey.toLowerCase();
    return k.contains('tts') ||
        k.contains('gpt-sovits') ||
        k.contains('sovits') ||
        k.contains('speech-synthesis') ||
        k.contains('voiceclone') ||
        k.contains('voicedesign') ||
        k.endsWith('-voice');
  }

  /// Detect TTS model type from model name.
  /// Returns 'clone', 'design', or 'preset'.
  static String _detectTtsModelType(String modelKey) {
    final k = modelKey.toLowerCase();
    if (k.contains('voiceclone') || k.contains('clone')) return 'clone';
    if (k.contains('voicedesign') || k.contains('design')) return 'design';
    return 'preset';
  }

  /// Load available voices for the selected model.
  /// For MiMo preset models: returns built-in voice list.
  /// For other providers: loads from cached voice entries.
  Future<void> _loadVoicesForModel(String modelKey) async {
    setState(() {
      _loadingSpeakers = true;
      _speakers = [];
      _selectedSpeaker = null;
      _voiceNameCtrl.clear();
    });

    List<String> voiceList = [];

    // MiMo TTS preset models have built-in voices
    final mimoVoices = ChatCompletionsTtsAdapter.builtInVoicesForMimoModel(
      modelKey,
    );
    if (mimoVoices.isNotEmpty && _ttsModelType == 'preset') {
      voiceList = mimoVoices;
    } else {
      // For other providers, load from cached voice entries
      final cachedVoices = await widget.database.getVoiceEntriesForProvider(
        _selectedProviderId,
      );
      voiceList = cachedVoices.map((b) => b.modelKey).toList()..sort();
    }

    if (mounted) {
      setState(() {
        _speakers = voiceList;
        _loadingSpeakers = false;
      });
    }
  }

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
        .firstWhere(
          (t) => t.name == adapterType,
          orElse: () => AdapterType.openaiCompatible,
        )
        .hasSeparateModelAndVoice;

    if (_isGptSovits) {
      final cachedVoices = await widget.database.getVoiceEntriesForProvider(
        _selectedProviderId,
      );
      if (cachedVoices.isNotEmpty) {
        final voices = cachedVoices.map((b) => b.modelKey).toList()..sort();
        if (mounted) {
          setState(() {
            _speakers = voices;
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        return;
      }

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
      return;
    }

    if (hasSeparate) {
      // Models from cache — filter to TTS-only models
      final cachedModels = await widget.database.getModelEntriesForProvider(
        _selectedProviderId,
      );
      final modelList =
          cachedModels
              .map((b) => b.modelKey)
              .where((k) => _isTtsModel(k))
              .toList()
            ..sort();

      if (mounted) {
        setState(() {
          _models = modelList;
          _loadingModels = false;
          _loadingSpeakers = false;
          // Auto-select model if only one
          if (modelList.length == 1) {
            _selectedModel = modelList.first;
            _modelNameCtrl.text = modelList.first;
            _ttsModelType = _detectTtsModelType(modelList.first);
            _loadVoicesForModel(modelList.first);
          }
        });
      }
    } else {
      // CosyVoice native exposes profiles via /cosyvoice/profiles — fetch them
      // so the user can pick a registered one instead of typing a name that
      // the server will reject.
      if (_isCosyVoice) {
        if (mounted) {
          setState(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        _fetchCosyVoiceProfiles();
        return;
      }
      // VoxCPM2 native exposes registered voices via /voxcpm/voices — same
      // rationale: clone mode's `voice_id` must match a registered id.
      if (_isVoxCpm2) {
        if (mounted) {
          setState(() {
            _loadingSpeakers = false;
            _loadingModels = false;
          });
        }
        _fetchVoxCpm2Voices();
        return;
      }
      // Voice-only providers (Azure, System TTS, GPT-SoVITS)
      final cached = await widget.database.getBindingsForProvider(
        _selectedProviderId,
      );
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
        ),
      ];
    }
    if (_speakers.isNotEmpty) {
      return [
        VoiceCharacterVoiceSearchPicker(
          label: label,
          voices: _speakers,
          selected: _selectedSpeaker,
          onSelected: (v) => setState(() {
            _selectedSpeaker = v;
            _voiceNameCtrl.text = v;
            _autoFillName();
          }),
        ),
        SizedBox(height: 8),
      ];
    }
    return [];
  }

  /// Build the reference audio picker with voice asset library support.
  List<Widget> _buildRefAudioPicker() {
    return [
      VoiceCharacterSectionLabel('REFERENCE AUDIO'),
      SizedBox(height: 8),
      // Pick from voice assets library
      if (widget.audioTracks.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).uiSelectFromVoiceAssets,
            prefixIcon: Icon(Icons.library_music_rounded, size: 18),
          ),
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                AppLocalizations.of(context).uiNoneUploadManually,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            ...widget.audioTracks.map(
              (t) => DropdownMenuItem(
                value: t.id,
                child: Text(t.name, overflow: TextOverflow.ellipsis),
              ),
            ),
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
        SizedBox(height: 10),
        if (_selectedAudioTrackId == null) ...[
          Text(
            AppLocalizations.of(context).uiOrUploadANewFile,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          SizedBox(height: 8),
        ],
      ],
      // Manual upload (shown when no track selected or no tracks exist)
      if (_selectedAudioTrackId == null)
        VoiceCharacterRefAudioPicker(
          path: _uploadedRefAudioPath,
          onPick: (path) => setState(() => _uploadedRefAudioPath = path),
        ),
      SizedBox(height: 12),
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
    final model = _modelNameCtrl.text.trim().isNotEmpty
        ? _modelNameCtrl.text.trim()
        : (_selectedModel ?? '');
    final speaker = _voiceNameCtrl.text.trim().isNotEmpty
        ? _voiceNameCtrl.text.trim()
        : (_selectedSpeaker ?? '');
    // Build: provider_model_voice (skip empty parts)
    final parts = <String>[providerName];
    if (model.isNotEmpty) parts.add(model);
    if (speaker.isNotEmpty) parts.add(speaker);
    _nameCtrl.text = parts.join('_');
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
                  Text(
                    AppLocalizations.of(context).uiNewVoiceCharacter,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                  VoiceCharacterSectionLabel('CHARACTER INFO'),
                  SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatarForCreate,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppTheme.accentColor.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage: _avatarPath != null
                                ? FileImage(File(_avatarPath!))
                                : null,
                            child: _avatarPath == null
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 36,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  )
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
                                  color: AppTheme.surfaceDim,
                                  width: 2,
                                ),
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiCharacterName,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Tooltip(
                        message: 'Auto-fill: Provider + Speaker',
                        child: IconButton(
                          onPressed: _autoFillName,
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.accentColor.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).uiDescriptionOptional,
                    ),
                  ),
                  SizedBox(height: 20),

                  // ── PROVIDER ──
                  VoiceCharacterSectionLabel('PROVIDER'),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).uiProvider,
                    ),
                    items: widget.providers
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
                    initialValue: _selectedProviderId,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedProviderId = v;
                        _cosyVoiceMode = null;
                        _gptSovitsMode = 'trained';
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
                  SizedBox(height: 20),

                  // ── ADAPTER-SPECIFIC OPTIONS ──
                  if (_isPresetVoiceProvider) ...[
                    if (_adapterType == 'openaiCompatible' ||
                        _adapterType == 'chatCompletionsTts' ||
                        _isGeminiTts) ...[
                      // ── Step 1: Select Model ──
                      VoiceCharacterSectionLabel('MODEL'),
                      SizedBox(height: 8),
                      if (_loadingModels)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(context).uiLoadingModels,
                              ),
                            ],
                          ),
                        )
                      else if (_models.isNotEmpty) ...[
                        VoiceCharacterVoiceSearchPicker(
                          label: AppLocalizations.of(context).uiSelectModel,
                          voices: _models,
                          selected: _selectedModel,
                          onSelected: (v) {
                            final modelType = _detectTtsModelType(v);
                            setState(() {
                              _selectedModel = v;
                              _modelNameCtrl.text = v;
                              _ttsModelType = modelType;
                              // Reset voice state when model changes
                              _selectedSpeaker = null;
                              _voiceNameCtrl.clear();
                              _uploadedRefAudioPath = null;
                              _selectedAudioTrackId = null;
                              _instructionCtrl.clear();
                            });
                            _loadVoicesForModel(v);
                            _autoFillName();
                          },
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).uiNoTTSModelsFoundGoToProvidersFetchAllToCacheAvailable,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],

                      // ── Step 2: Contextual UI based on selected model type ──
                      if (_selectedModel != null && _ttsModelType != null) ...[
                        SizedBox(height: 16),

                        // ── Preset Voice: voice picker ──
                        if (_ttsModelType == 'preset') ...[
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    AppLocalizations.of(
                                      context,
                                    ).uiLoadingVoices,
                                  ),
                                ],
                              ),
                            )
                          else if (_speakers.isNotEmpty)
                            VoiceCharacterVoiceSearchPicker(
                              label: AppLocalizations.of(context).uiSelectVoice,
                              voices: _speakers,
                              selected: _selectedSpeaker,
                              onSelected: (v) => setState(() {
                                _selectedSpeaker = v;
                                _voiceNameCtrl.text = v;
                                _autoFillName();
                              }),
                            ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _voiceNameCtrl,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).uiVoiceSpeakerID,
                              hintText: AppLocalizations.of(
                                context,
                              ).uiEGAlloyOrGenshinPaimon,
                            ),
                            onChanged: (_) => _autoFillName(),
                          ),
                          if (_isGeminiTts) ...[
                            SizedBox(height: 16),
                            VoiceCharacterSectionLabel(
                              'STYLE INSTRUCTION (optional)',
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: _instructionCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(
                                  context,
                                ).uiStyleInstruction,
                                hintText: AppLocalizations.of(
                                  context,
                                ).uiEGSpeakSoftlyAndSlowlyPrependedToTheText,
                              ),
                            ),
                          ],
                        ],

                        // ── Voice Clone: ref audio upload ──
                        if (_ttsModelType == 'clone') ...[
                          ..._buildRefAudioPicker(),
                          VoiceCharacterSectionLabel('VOICE NAME (optional)'),
                          SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).uiALabelForThisClonedVoiceTheActualVoiceIsDerivedFrom,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _voiceNameCtrl,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).uiVoiceName,
                              hintText: AppLocalizations.of(
                                context,
                              ).uiEGMyClonedVoice,
                            ),
                          ),
                        ],

                        // ── Voice Design: text description ──
                        if (_ttsModelType == 'design') ...[
                          VoiceCharacterSectionLabel('VOICE DESCRIPTION'),
                          SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).uiDescribeTheVoiceYouWantToCreateThisWillBeUsedTo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _instructionCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).uiVoiceDescription,
                              hintText: AppLocalizations.of(
                                context,
                              ).uiEGHeavyRussianAccentGruffMiddleAgedMale,
                            ),
                          ),
                        ],
                      ],
                    ] else ...[
                      // ── Azure / System TTS: voices only ──
                      VoiceCharacterSectionLabel(
                        _adapterType == 'azureTts' ? 'VOICE' : 'PRESET VOICE',
                      ),
                      SizedBox(height: 8),
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
                    VoiceCharacterSectionLabel('COSYVOICE MODE'),
                    SizedBox(height: 8),
                    VoiceCharacterCosyVoiceModeSelector(
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
                    SizedBox(height: 20),
                    if (_cosyVoiceMode != null) ...[
                      VoiceCharacterSectionLabel('SERVER PROFILE (optional)'),
                      SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).uiAProfileRegisteredOnTheCosyVoiceServerLeaveAsNoneToSynthesise,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      SizedBox(height: 8),
                      if (_loadingCosyProfiles)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).uiLoadingServerProfiles,
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiServerProfile,
                            prefixIcon: Icon(
                              Icons.folder_shared_rounded,
                              size: 18,
                            ),
                          ),
                          isExpanded: true,
                          initialValue: _selectedCosyProfileId,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).uiNoneUseUploadedAudioOnly,
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                            ..._cosyProfiles.map(
                              (p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(
                                  p.modeLabel.isNotEmpty
                                      ? '${p.name}  ·  ${p.modeLabel}'
                                      : p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedCosyProfileId = v;
                            _voiceNameCtrl.text = v ?? '';
                          }),
                        ),
                      SizedBox(height: 12),

                      // ── Zero Shot ──────────────────────────────────────────
                      if (_cosyVoiceMode == 'zero_shot') ...[
                        ..._buildRefAudioPicker(),
                        TextField(
                          controller: _promptTextCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiPromptTextSpokenInRefAudio,
                            hintText: AppLocalizations.of(
                              context,
                            ).uiTranscriptOfTheReferenceAudio,
                          ),
                        ),
                        SizedBox(height: 10),
                        TextField(
                          controller: _promptLangCtrl,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiLanguageCode,
                            hintText: AppLocalizations.of(context).uiZhEnJaKo,
                          ),
                        ),
                      ],

                      // ── Cross Lingual ──────────────────────────────────────
                      if (_cosyVoiceMode == 'cross_lingual') ...[
                        VoiceCharacterSectionLabel('REFERENCE AUDIO'),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).uiUploadAVoiceSampleTheModelWillCloneItsToneAndSpeak,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 8),
                        ..._buildRefAudioPicker(),
                      ],

                      // ── Instruct ───────────────────────────────────────────
                      if (_cosyVoiceMode == 'instruct') ...[
                        VoiceCharacterSectionLabel('INSTRUCT'),
                        SizedBox(height: 8),
                        TextField(
                          controller: _instructionCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiInstructText,
                            hintText: AppLocalizations.of(
                              context,
                            ).uiEGOrSpeakWithExcitement,
                          ),
                        ),
                        SizedBox(height: 16),
                        VoiceCharacterSectionLabel(
                          'REFERENCE AUDIO (optional)',
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).uiUploadAVoiceSampleToUseAsTheBaseVoiceInsteadOf,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 8),
                        ..._buildRefAudioPicker(),
                      ],
                    ],
                  ] else if (_isVoxCpm2) ...[
                    // ── VoxCPM2 Native: 3 modes ──
                    VoiceCharacterSectionLabel('VOXCPM2 MODE'),
                    SizedBox(height: 8),
                    VoiceCharacterVoxCpm2ModeSelector(
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
                    SizedBox(height: 20),
                    if (_voxcpmMode != null) ...[
                      // Registered voice picker (optional — only meaningful in
                      // clone / ultimate_clone; for design we still show it
                      // disabled-via-empty-list so the UI is consistent).
                      if (_voxcpmMode != 'design') ...[
                        VoiceCharacterSectionLabel(
                          'REGISTERED VOICE (optional)',
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).uiAVoiceProfileRegisteredOnTheServerLeaveAsNoneToSynthesise,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 8),
                        if (_loadingVoxcpmVoices)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).uiLoadingRegisteredVoices,
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<String?>(
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).uiRegisteredVoice,
                              prefixIcon: Icon(
                                Icons.folder_shared_rounded,
                                size: 18,
                              ),
                            ),
                            isExpanded: true,
                            initialValue: _selectedVoxcpmVoiceId,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).uiNoneUseUploadedAudioOnly,
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                              ..._voxcpmVoices.map(
                                (v) => DropdownMenuItem<String?>(
                                  value: v.id,
                                  child: Text(
                                    v.displayName.isNotEmpty
                                        ? '${v.displayName}  ·  ${v.id}'
                                        : v.id,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedVoxcpmVoiceId = v;
                              _voiceNameCtrl.text = v ?? '';
                            }),
                          ),
                        SizedBox(height: 12),
                      ],

                      // ── Design ─────────────────────────────────────────────
                      if (_voxcpmMode == 'design') ...[
                        VoiceCharacterSectionLabel('VOICE DESCRIPTION'),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).uiNaturalLanguageVoiceDescriptionAtSynthesisTimePrependItToTheText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _instructionCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiVoiceDescription,
                            hintText: AppLocalizations.of(
                              context,
                            ).uiAYoungWomanGentleAndSweetVoice,
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
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(
                              context,
                            ).uiPromptTextSpokenInRefAudio2,
                            hintText: AppLocalizations.of(
                              context,
                            ).uiTranscriptOfTheReferenceAudio,
                          ),
                        ),
                      ],
                    ],
                  ] else if (_isGptSovits) ...[
                    VoiceCharacterSectionLabel('GPT-SOVITS MODE'),
                    SizedBox(height: 8),
                    VoiceCharacterGptSovitsModeSelector(
                      selected: _gptSovitsMode,
                      onChanged: (mode) {
                        setState(() {
                          _gptSovitsMode = mode;
                          _taskMode = mode == 'clone'
                              ? TaskMode.cloneWithPrompt
                              : TaskMode.presetVoice;
                          _selectedAudioTrackId = null;
                          _uploadedRefAudioPath = null;
                          if (mode == 'trained') {
                            _promptTextCtrl.clear();
                          }
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    if (_gptSovitsMode == 'trained') ...[
                      VoiceCharacterSectionLabel('TRAINED SPEAKER'),
                      SizedBox(height: 8),
                      ..._buildSpeakerPicker(
                        label: AppLocalizations.of(context).uiSelectSpeaker,
                      ),
                      TextField(
                        controller: _voiceNameCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiSpeakerVoiceID,
                          hintText: AppLocalizations.of(
                            context,
                          ).uiEGGenshinPaimon,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _textLangCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiTextLanguageOptional,
                          hintText: AppLocalizations.of(context).uiZhEnJaKo,
                        ),
                      ),
                    ] else ...[
                      ..._buildRefAudioPicker(),
                      TextField(
                        controller: _promptTextCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiPromptTextSpokenInRefAudio2,
                          hintText: AppLocalizations.of(
                            context,
                          ).uiTranscriptOfTheReferenceAudio,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: _promptLangCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiPromptLanguage,
                          hintText: AppLocalizations.of(context).uiZhEnJaKo,
                        ),
                      ),
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
                      SizedBox(height: 10),
                      TextField(
                        controller: _voiceNameCtrl,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).uiOutputSpeakerNameOptional,
                          hintText: AppLocalizations.of(context).uiEGClone,
                        ),
                      ),
                    ],
                  ] else ...[
                    // ── Fallback for other adapters (qwen3, etc.) ──
                    VoiceCharacterSectionLabel('VOICE'),
                    SizedBox(height: 8),
                    ..._buildSpeakerPicker(),
                    TextField(
                      controller: _voiceNameCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).uiVoiceSpeakerName,
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                ],
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).uiCancel),
                  ),
                  const Spacer(),
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
                    label: Text(AppLocalizations.of(context).uiCreateCharacter),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).uiNameIsRequired)),
      );
      return;
    }

    final refAudio = _effectiveRefAudioPath;
    // GPT-SoVITS and CosyVoice zero_shot / cross_lingual require ref audio.
    // cross_lingual can skip it only if a profile name is given instead.
    // VoxCPM2 clone / ultimate_clone need ref audio unless a registered
    // voice_id is chosen.
    // ChatCompletionsTts clone models need ref audio.
    final voxcpmNeedsAudio =
        _isVoxCpm2 &&
        (_voxcpmMode == 'clone' || _voxcpmMode == 'ultimate_clone') &&
        _voiceNameCtrl.text.trim().isEmpty;
    final chatCloneNeedsAudio =
        _isPresetVoiceProvider && _ttsModelType == 'clone';
    final needsRefAudio =
        (_isGptSovits && _gptSovitsMode == 'clone') ||
        (_isCosyVoice && _cosyVoiceMode == 'zero_shot') ||
        (_isCosyVoice &&
            _cosyVoiceMode == 'cross_lingual' &&
            _voiceNameCtrl.text.trim().isEmpty) ||
        voxcpmNeedsAudio ||
        chatCloneNeedsAudio;
    if (needsRefAudio && refAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCosyVoice && _cosyVoiceMode == 'cross_lingual'
                ? 'Cross Lingual mode requires a Reference Audio or a Profile Name'
                : _isVoxCpm2
                ? 'VoxCPM2 ${_voxcpmMode == 'ultimate_clone' ? 'Ultra Clone' : 'Clone'} needs a Reference Audio or a Registered Voice'
                : 'Reference audio is required',
          ),
        ),
      );
      return;
    }
    if (_isGptSovits &&
        _gptSovitsMode == 'trained' &&
        _voiceNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiSelectOrEnterAGPTSoVITSSpeaker,
          ),
        ),
      );
      return;
    }
    if (_isGptSovits &&
        _gptSovitsMode == 'clone' &&
        _promptTextCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiGPTSoVITSCloneModeNeedsPromptText,
          ),
        ),
      );
      return;
    }
    if (_isVoxCpm2 && _voxcpmMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).uiSelectAVoxCPM2Mode),
        ),
      );
      return;
    }
    if (_isVoxCpm2 &&
        _voxcpmMode == 'design' &&
        _instructionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiDesignModeRequiresAVoiceDescription,
          ),
        ),
      );
      return;
    }
    if (_isPresetVoiceProvider &&
        _ttsModelType == 'design' &&
        _instructionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiVoiceDesignRequiresAVoiceDescription,
          ),
        ),
      );
      return;
    }
    if (_isVoxCpm2 &&
        _voxcpmMode == 'ultimate_clone' &&
        _promptTextCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).uiUltraCloneModeRequiresAPromptText,
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Determine task mode
    TaskMode effectiveMode;
    if (_isPresetVoiceProvider) {
      if (_ttsModelType == 'clone') {
        effectiveMode = TaskMode.cloneWithPrompt;
      } else if (_ttsModelType == 'design') {
        effectiveMode = TaskMode.voiceDesign;
      } else {
        effectiveMode = TaskMode.presetVoice;
      }
    } else if (_isGptSovits) {
      effectiveMode = _gptSovitsMode == 'clone'
          ? TaskMode.cloneWithPrompt
          : TaskMode.presetVoice;
    } else {
      effectiveMode = _taskMode;
    }

    final assetId = const Uuid().v4();

    // Copy avatar to persistent location if picked
    String? persistedAvatarPath;
    if (_avatarPath != null) {
      try {
        final avatarDir = await PathService.instance.avatarsDir();
        final ext = p.extension(_avatarPath!);
        final dest = p.join(avatarDir.path, '$assetId$ext');
        await File(_avatarPath!).copy(dest);
        persistedAvatarPath = dest;
      } catch (_) {}
    }

    // Auto-save manually uploaded ref audio to voice assets library
    if (_uploadedRefAudioPath != null && _selectedAudioTrackId == null) {
      try {
        final vaDir = await PathService.instance.voiceCharacterRefDir();
        final trackId = const Uuid().v4();
        final ext = p.extension(_uploadedRefAudioPath!);
        final base = p.basenameWithoutExtension(_uploadedRefAudioPath!);
        final dest = PathService.dedupeFilename(
          vaDir,
          '${PathService.sanitizeSegment(base, fallback: 'ref')}_${PathService.formatTimestamp()}',
          ext,
        );
        await File(_uploadedRefAudioPath!).copy(dest);
        await widget.onSaveAudioTrack(
          db.AudioTracksCompanion(
            id: Value(trackId),
            name: Value(base),
            audioPath: Value(dest),
            refText: Value(
              _promptTextCtrl.text.trim().isEmpty
                  ? null
                  : _promptTextCtrl.text.trim(),
            ),
            refLang: Value(
              _promptLangCtrl.text.trim().isEmpty
                  ? null
                  : _promptLangCtrl.text.trim(),
            ),
            sourceType: const Value('upload'),
            createdAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {}
    }

    await widget.onSave(
      db.VoiceAssetsCompanion(
        id: Value(assetId),
        name: Value(name),
        description: Value(
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        ),
        providerId: Value(_selectedProviderId),
        modelBindingId: const Value(null),
        modelName: Value(
          _isGptSovits
              ? (_textLangCtrl.text.trim().isEmpty
                    ? null
                    : _textLangCtrl.text.trim())
              : (_adapterType == 'openaiCompatible' ||
                    _adapterType == 'chatCompletionsTts' ||
                    _isGeminiTts)
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
              : null,
        ),
        taskMode: Value(effectiveMode.name),
        refAudioPath: Value(refAudio),
        refAudioTrimStart: const Value(null),
        refAudioTrimEnd: const Value(null),
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
        presetVoiceName: Value(
          _voiceNameCtrl.text.trim().isEmpty
              ? null
              : _voiceNameCtrl.text.trim(),
        ),
        avatarPath: Value(persistedAvatarPath),
      ),
    );

    if (mounted) Navigator.pop(context);
  }
}

// ─────────────────────────── Sub-widgets ────────────────────────────────────
