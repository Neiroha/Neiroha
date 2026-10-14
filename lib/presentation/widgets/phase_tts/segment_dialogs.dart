part of 'segment_voice_panel.dart';

extension _SegmentDialogs on _SegmentVoicePanelState {
  Future<void> _openSettingsDialog(db.PhaseTtsSegment segment) async {
    final current =
        _settings.bySegmentId[segment.id] ?? const SegmentVoiceSettings();
    var selectedVoiceId = segment.voiceAssetId;
    final instructionCtrl = TextEditingController(
      text: current.voiceInstruction ?? '',
    );
    final audioTagCtrl = TextEditingController(
      text: current.audioTagPrefix ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = AppLocalizations.of(context);
            final selectedAsset = widget.bankAssets
                .where((asset) => asset.id == selectedVoiceId)
                .firstOrNull;
            final provider = _providerFor(selectedAsset);
            final supportsInstruction =
                selectedAsset != null &&
                provider != null &&
                VoiceCapabilities.supportsVoiceInstruction(
                  selectedAsset,
                  provider,
                );
            final supportsAudioTag =
                selectedAsset != null &&
                provider != null &&
                VoiceCapabilities.supportsAudioTags(selectedAsset, provider);

            return AlertDialog(
              title: Text(l10n.uiSentenceVoice),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      segment.segmentText,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                    _VoiceDropdown(
                      value: selectedVoiceId,
                      assets: widget.bankAssets,
                      hintText: l10n.uiVoice,
                      onChanged: (id) =>
                          setDialogState(() => selectedVoiceId = id),
                    ),
                    SizedBox(height: 10),
                    if (supportsInstruction)
                      TextField(
                        controller: instructionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.uiStyleDirection,
                          hintText: '焦虑地说，压低声音，语速稍快',
                        ),
                      ),
                    if (supportsAudioTag) ...[
                      SizedBox(height: 10),
                      TextField(
                        controller: audioTagCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.uiAudioTagPrefix,
                          hintText: '(紧张|深呼吸)',
                        ),
                      ),
                    ],
                    if (!supportsInstruction && !supportsAudioTag) ...[
                      SizedBox(height: 10),
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: l10n.uiNoPerSentenceStyleControls,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    instructionCtrl.clear();
                    audioTagCtrl.clear();
                    setDialogState(() => selectedVoiceId = null);
                  },
                  child: Text(l10n.uiClear),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.uiCancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedVoiceId != segment.voiceAssetId) {
                      _changeSegmentVoice(segment, selectedVoiceId);
                    }
                    _setSegmentSettings(
                      segment.id,
                      SegmentVoiceSettings(
                        voiceInstruction: supportsInstruction
                            ? _normalizeText(instructionCtrl.text)
                            : null,
                        audioTagPrefix: supportsAudioTag
                            ? _normalizeText(audioTagCtrl.text)
                            : null,
                      ),
                      saveNow: true,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(l10n.uiSave),
                ),
              ],
            );
          },
        );
      },
    );

    instructionCtrl.dispose();
    audioTagCtrl.dispose();
  }

  String? _normalizeText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Multi-line text prompt shared by edit / insert.
  Future<String?> _promptText({
    required String title,
    required String initial,
    required String actionLabel,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.uiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _openEditTextDialog(db.PhaseTtsSegment segment) async {
    final l10n = AppLocalizations.of(context);
    final next = await _promptText(
      title: l10n.phaseEditText,
      initial: segment.segmentText,
      actionLabel: l10n.uiSave,
      hint: segment.audioPath != null ? l10n.phaseEditTextHint : null,
    );
    if (next == null || next.isEmpty || next == segment.segmentText) return;
    await widget.onEditText(segment, next);
  }

  Future<void> _openInsertDialog(db.PhaseTtsSegment? after) async {
    final l10n = AppLocalizations.of(context);
    final text = await _promptText(
      title: l10n.phaseInsertTitle,
      initial: '',
      actionLabel: l10n.phaseInsertAction,
    );
    if (text == null || text.isEmpty) return;
    await widget.onInsertAfter(after, text);
  }

  /// Split at the cursor; the cursor starts at the punctuation closest to
  /// the middle so a single click on "Split here" is usually enough.
  Future<void> _openSplitDialog(db.PhaseTtsSegment segment) async {
    final text = segment.segmentText;
    final controller = TextEditingController(text: text);
    controller.selection = TextSelection.collapsed(
      offset: _suggestSplitOffset(text),
    );
    final at = await showDialog<int>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.phaseSplitTitle),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.phaseSplitHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  autofocus: true,
                  readOnly: true,
                  showCursor: true,
                  minLines: 3,
                  maxLines: 8,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.uiCancel),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, controller.selection.baseOffset),
              icon: const Icon(Icons.call_split_rounded, size: 16),
              label: Text(l10n.phaseSplitAction),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (at == null || at <= 0 || at >= text.length) return;
    final head = text.substring(0, at).trim();
    final tail = text.substring(at).trim();
    if (head.isEmpty || tail.isEmpty) return;
    await widget.onSplit(segment, head, tail);
  }
}
