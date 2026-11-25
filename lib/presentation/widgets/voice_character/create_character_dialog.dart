import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/data/ai/registry/built_in_voices.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/ai/providers/local/cosyvoice/tts/cosyvoice_adapter.dart';
import 'package:neiroha/data/ai/providers/local/irodori/tts/irodori_adapter.dart';
import 'package:neiroha/data/ai/providers/local/voxcpm2/tts/voxcpm2_native_adapter.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/synthesis/browser_speech_support.dart';
import 'package:neiroha/data/storage/path_service.dart';
import 'package:neiroha/domain/enums/adapter_type.dart';
import 'package:neiroha/domain/enums/task_mode.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/voice_character/components.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/actions/browser_speech_message.dart';
import 'editable_character_avatar.dart';
import 'preset_voice_style_fields.dart';

part 'create_character_loading.dart';
part 'create_character_local_fields.dart';
part 'create_character_other_fields.dart';
part 'create_character_preset_fields.dart';
part 'create_character_save.dart';

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

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

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
  bool get _isIrodori => _adapterType == 'irodori';
  bool get _isPresetVoiceProvider =>
      _adapterType == 'chatCompletionsTts' ||
      _adapterType == 'openaiCompatible' ||
      _isOpenAiTts ||
      _adapterType == 'azureTts' ||
      _adapterType == 'systemTts' ||
      _adapterType == 'geminiTts' ||
      _isIrodori ||
      _isCloudCloneProvider;
  bool get _isGeminiTts => _adapterType == 'geminiTts';
  bool get _isOpenAiTts => _adapterType == 'openaiTts';
  bool get _isIndexTts => _adapterType == 'indexTts';

  /// ElevenLabs / MiniMax: preset voices plus optional server-side cloning
  /// that registers a reusable voice id on the user's account.
  bool get _isCloudCloneProvider =>
      _adapterType == 'elevenLabs' || _adapterType == 'minimaxTts';

  /// Providers whose characters pick a model first, then a voice.
  bool get _usesModelThenVoice =>
      _adapterType == 'openaiCompatible' ||
      _isOpenAiTts ||
      _adapterType == 'chatCompletionsTts' ||
      _isGeminiTts ||
      _isIrodori ||
      _isCloudCloneProvider;

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
                  VoiceCharacterSectionLabel(
                    AppLocalizations.of(context).sectionCharacterInfo,
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: EditableCharacterAvatar(
                      onEdit: kIsWeb ? null : _pickAvatarForCreate,
                      avatar: CircleAvatar(
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
                                color: context.fg.withValues(alpha: 0.3),
                              )
                            : null,
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
                        message: AppLocalizations.of(
                          context,
                        ).autoFillProviderSpeaker,
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
                  VoiceCharacterSectionLabel(
                    AppLocalizations.of(context).sectionProvider,
                  ),
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
                                    color: context.fg.withValues(alpha: 0.4),
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
                  if (_isPresetVoiceProvider)
                    ..._presetVoiceFields()
                  else if (_isCosyVoice)
                    ..._cosyVoiceFields()
                  else if (_isVoxCpm2)
                    ..._voxCpm2Fields()
                  else if (_isGptSovits)
                    ..._gptSovitsFields()
                  else if (_isIndexTts)
                    ..._indexTtsFields()
                  else
                    ..._genericFields(),
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
}
