import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/actions/file_dialogs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part 'mode_selectors.dart';

class VoiceCharacterRefAudioPicker extends ConsumerWidget {
  final String? path;
  final ValueChanged<String> onPick;

  const VoiceCharacterRefAudioPicker({
    super.key,
    required this.path,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(
      playbackNotifierProvider.select(
        (state) => (audioPath: state.audioPath, isPlaying: state.isPlaying),
      ),
    );
    final isPlaying =
        path != null && playback.audioPath == path && playback.isPlaying;
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: path != null
                ? Colors.green.withValues(alpha: 0.4)
                : context.fg.withValues(alpha: 0.1),
          ),
        ),
        child: path == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    color: context.fg.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context).uiClickToSelectAudioFile,
                    style: TextStyle(color: context.fg.withValues(alpha: 0.4)),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.audio_file_rounded, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path!.split(Platform.pathSeparator).last,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppLocalizations.of(context).uiTapToChange,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.fg.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play / stop preview
                  IconButton(
                    onPressed: () async {
                      final n = ref.read(playbackNotifierProvider.notifier);
                      if (isPlaying) {
                        await n.stop();
                      } else {
                        await n.load(
                          path!,
                          path!.split(Platform.pathSeparator).last,
                        );
                      }
                    },
                    icon: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    ),
                    tooltip: isPlaying ? 'Stop' : 'Preview',
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await pickFiles(type: FileType.audio, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      onPick(result.files.single.path!);
    }
  }
}

class VoiceCharacterAvatar extends StatelessWidget {
  final String name;
  final bool selected;
  final double radius;
  final String? avatarPath;
  const VoiceCharacterAvatar({
    super.key,
    required this.name,
    required this.selected,
    this.radius = 20,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && avatarPath != null && File(avatarPath!).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(avatarPath!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: selected ? AppTheme.accentColor : context.colors.divider,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: radius * 0.75,
          color: selected ? Colors.white : context.fg,
        ),
      ),
    );
  }
}

class VoiceCharacterModeBadge extends StatelessWidget {
  final String mode;
  const VoiceCharacterModeBadge({super.key, required this.mode});

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

class VoiceCharacterSectionLabel extends StatelessWidget {
  final String text;
  const VoiceCharacterSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: context.fg.withValues(alpha: 0.4),
    ),
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
class VoiceCharacterVoiceSearchPicker extends StatefulWidget {
  final String label;
  final List<String> voices;
  final String? selected;
  final ValueChanged<String> onSelected;

  const VoiceCharacterVoiceSearchPicker({
    super.key,
    required this.label,
    required this.voices,
    required this.onSelected,
    this.selected,
  });

  @override
  State<VoiceCharacterVoiceSearchPicker> createState() =>
      _VoiceSearchPickerState();
}

class _VoiceSearchPickerState extends State<VoiceCharacterVoiceSearchPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.voices;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void didUpdateWidget(covariant VoiceCharacterVoiceSearchPicker old) {
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

  void _onSearch() =>
      setState(() => _filtered = _applyFilter(_searchCtrl.text));

  void _toggleOpen() => setState(() {
    _isOpen = !_isOpen;
    if (!_isOpen) _searchCtrl.clear();
  });

  void _selectItem(String voice) {
    widget.onSelected(voice);
    setState(() {
      _isOpen = false;
      _searchCtrl.clear();
    });
  }

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
        // Display field — tap to toggle dropdown
        GestureDetector(
          onTap: _toggleOpen,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: Icon(
                _isOpen
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 20,
                color: context.fg.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              widget.selected ?? '${widget.voices.length} available',
              style: TextStyle(
                fontSize: 14,
                color: widget.selected != null
                    ? context.fg
                    : context.fg.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        // Search field + filtered list — only shown when open
        if (_isOpen) ...[
          SizedBox(height: 4),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).uiSearch,
              prefixIcon: const Icon(Icons.filter_list_rounded, size: 18),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          SizedBox(height: 4),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: context.colors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.fg.withValues(alpha: 0.08)),
            ),
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No match "${_searchCtrl.text}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fg.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final voice = _filtered[i];
                      final isSelected = voice == widget.selected;
                      return InkWell(
                        onTap: () => _selectItem(voice),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: isSelected
                              ? AppTheme.accentColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  voice,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? AppTheme.accentColor
                                        : context.fg.withValues(alpha: 0.85),
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
      ],
    );
  }
}
