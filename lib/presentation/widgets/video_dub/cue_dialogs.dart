import 'package:flutter/material.dart';
import 'package:neiroha/data/database/app_database.dart' as db;

/// Result of [showCueEditDialog]. `autoTts` / `autoSync` are only set
/// when the dialog was rendered with `showAutoSwitches: true` (the
/// Add-cue path); Edit-cue ignores both. `voiceAssetId` is the user's
/// pick from the voice dropdown — `null` when the dialog wasn't asked
/// to render the dropdown or when the bank has no voices.
class CueEdit {
  final int startMs;
  final int endMs;
  final String text;
  final bool autoTts;
  final bool autoSync;
  final String? voiceAssetId;
  const CueEdit({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.autoTts = false,
    this.autoSync = false,
    this.voiceAssetId,
  });
}

/// Shared editor dialog for both Add-cue and Edit-cue flows. Pass
/// `showAutoSwitches: true` (Add only) to render the auto-TTS / auto-sync
/// toggles; `voiceAssets` (Add only) renders the voice picker.
Future<CueEdit?> showCueEditDialog({
  required BuildContext context,
  required int initialStartMs,
  required int initialEndMs,
  required String initialText,
  required String title,
  bool showAutoSwitches = false,
  bool initialAutoTts = false,
  bool initialAutoSync = false,
  List<db.VoiceAsset>? voiceAssets,
  String? initialVoiceId,
}) async {
  final startCtrl = TextEditingController(text: _msToStamp(initialStartMs));
  final endCtrl = TextEditingController(text: _msToStamp(initialEndMs));
  final textCtrl = TextEditingController(text: initialText);
  String? errorMsg;
  var autoTts = initialAutoTts;
  var autoSync = initialAutoSync;
  String? selectedVoiceId;
  if (voiceAssets != null && voiceAssets.isNotEmpty) {
    final has =
        initialVoiceId != null &&
        voiceAssets.any((v) => v.id == initialVoiceId);
    selectedVoiceId = has ? initialVoiceId : voiceAssets.first.id;
  }

  try {
    return await showDialog<CueEdit>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Start (mm:ss.ms)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        decoration: const InputDecoration(
                          labelText: 'End (mm:ss.ms)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(labelText: 'Subtitle text'),
                ),
                if (voiceAssets != null && voiceAssets.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Voice',
                      isDense: true,
                    ),
                    isExpanded: true,
                    initialValue: selectedVoiceId,
                    items: [
                      for (final a in voiceAssets)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => selectedVoiceId = v),
                  ),
                ],
                if (showAutoSwitches) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Auto-generate TTS'),
                    subtitle: const Text(
                      'Run TTS for this cue immediately after saving. Needs a voice in the bank.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: autoTts,
                    onChanged: (v) => setDialogState(() => autoTts = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Auto-sync length to audio'),
                    subtitle: const Text(
                      'After generating, snap the End time to the actual TTS length.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: autoSync,
                    onChanged: (v) => setDialogState(() => autoSync = v),
                  ),
                ],
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final startMs = parseTimestamp(startCtrl.text);
                final endMs = parseTimestamp(endCtrl.text);
                if (startMs == null || endMs == null) {
                  setDialogState(
                    () => errorMsg = 'Use format mm:ss.ms or HH:mm:ss.ms',
                  );
                  return;
                }
                if (endMs <= startMs) {
                  setDialogState(
                    () => errorMsg = 'End must be greater than start',
                  );
                  return;
                }
                if (textCtrl.text.trim().isEmpty) {
                  setDialogState(() => errorMsg = 'Text is required');
                  return;
                }
                Navigator.pop(
                  ctx,
                  CueEdit(
                    startMs: startMs,
                    endMs: endMs,
                    text: textCtrl.text.trim(),
                    autoTts: showAutoSwitches && autoTts,
                    autoSync: showAutoSwitches && autoSync,
                    voiceAssetId: selectedVoiceId,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  } finally {
    startCtrl.dispose();
    endCtrl.dispose();
    textCtrl.dispose();
  }
}

/// SRT/LRC bulk-import options dialog. The caller passes the discovered
/// cue counts and the current sticky preferences; the result tells the
/// caller whether to replace, plus the (possibly updated) auto-flow flags.
typedef ImportSubtitlesChoice = ({bool replace, bool autoTts, bool autoSync});

Future<ImportSubtitlesChoice?> showImportSubtitlesDialog({
  required BuildContext context,
  required int cueCount,
  required int existingCount,
  required bool initialAutoTts,
  required bool initialAutoSync,
}) {
  var autoTts = initialAutoTts;
  var autoSync = initialAutoSync;
  return showDialog<ImportSubtitlesChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Import $cueCount cues?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existingCount == 0
                  ? 'Cues will be added to this project.'
                  : 'This project already has $existingCount cues. '
                        'Replace them, or append the new cues after?',
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Auto-generate TTS after import'),
              subtitle: const Text(
                'Run Generate All immediately. Cues without a voice are skipped.',
                style: TextStyle(fontSize: 11),
              ),
              value: autoTts,
              onChanged: (v) => setDialogState(() => autoTts = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Auto-sync cue lengths to audio'),
              subtitle: const Text(
                'After generating, snap each cue end to its TTS length.',
                style: TextStyle(fontSize: 11),
              ),
              value: autoSync,
              onChanged: (v) => setDialogState(() => autoSync = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (existingCount > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, (
                replace: false,
                autoTts: autoTts,
                autoSync: autoSync,
              )),
              child: const Text('Append'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              replace: true,
              autoTts: autoTts,
              autoSync: autoSync,
            )),
            child: Text(existingCount == 0 ? 'Import' : 'Replace'),
          ),
        ],
      ),
    ),
  );
}

/// Confirm-destructive dialog for the "Clear all cues" action. The
/// caller is responsible for the actual delete + dirty-flag bookkeeping.
Future<bool> showClearCuesConfirmDialog(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Clear all cues?'),
      content: const Text(
        'Cues will be removed. Generated audio files on disk are kept '
        'but the references will be gone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  return confirm == true;
}

String _msToStamp(int ms) {
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final msR = d.inMilliseconds.remainder(1000);
  String two(int n) => n.toString().padLeft(2, '0');
  final tail = '${two(m)}:${two(s)}.${msR.toString().padLeft(3, '0')}';
  return h > 0 ? '${two(h)}:$tail' : tail;
}

/// Parses a timestamp like `mm:ss`, `mm:ss.ms`, `HH:mm:ss`, or
/// `HH:mm:ss.ms` into milliseconds. Returns `null` for unparseable input.
int? parseTimestamp(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final m = RegExp(
    r'^(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})(?:[.,](\d{1,3}))?$',
  ).firstMatch(s);
  if (m == null) return null;
  final hours = m.group(1) == null ? 0 : int.parse(m.group(1)!);
  final minutes = int.parse(m.group(2)!);
  final seconds = int.parse(m.group(3)!);
  final msGroup = m.group(4);
  final ms = msGroup == null ? 0 : int.parse(msGroup.padRight(3, '0'));
  return ((hours * 3600) + (minutes * 60) + seconds) * 1000 + ms;
}
