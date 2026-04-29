import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/widgets/dialog_tts/voice_picker.dart';

/// Right-pane settings panel for the Dialog TTS editor.
///
/// Stacked sections from top to bottom:
///   STATS — line counts, generated/pending, total duration
///   SETTINGS — auto-generate-on-send, auto-play-after-generate toggles
///   GENERATION — Generate All button
///   VOICES IN BANK — searchable voice picker, takes the remaining height
class SettingsPanel extends StatelessWidget {
  final AsyncValue<List<db.DialogTtsLine>> linesAsync;
  final List<db.VoiceAsset> bankAssets;
  final String? activeVoiceId;
  final bool generatingAll;
  final bool autoGenerateOnSend;
  final bool autoPlayAfterGenerate;
  final ValueChanged<String> onPickVoice;
  final ValueChanged<bool> onToggleAutoGenerate;
  final ValueChanged<bool> onToggleAutoPlay;
  final VoidCallback onGenerateAll;

  const SettingsPanel({
    super.key,
    required this.linesAsync,
    required this.bankAssets,
    required this.activeVoiceId,
    required this.generatingAll,
    required this.autoGenerateOnSend,
    required this.autoPlayAfterGenerate,
    required this.onPickVoice,
    required this.onToggleAutoGenerate,
    required this.onToggleAutoPlay,
    required this.onGenerateAll,
  });

  @override
  Widget build(BuildContext context) {
    final lines = linesAsync.valueOrNull ?? const [];
    final pending = lines
        .where((l) => l.audioPath == null && l.voiceAssetId != null)
        .length;
    final ready = lines.where((l) => l.audioPath != null).length;
    final totalSec = lines
        .where((l) => l.audioPath != null && l.audioDuration != null)
        .fold<double>(0, (a, l) => a + (l.audioDuration ?? 0));

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('STATS'),
                const SizedBox(height: 8),
                _statTile(
                    icon: Icons.format_list_bulleted_rounded,
                    label: 'Lines',
                    value: '${lines.length}'),
                _statTile(
                    icon: Icons.task_alt_rounded,
                    label: 'Generated',
                    value: '$ready / ${lines.length}'),
                _statTile(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pending',
                    value: '$pending'),
                _statTile(
                    icon: Icons.timer_rounded,
                    label: 'Total length',
                    value: _formatDuration(totalSec)),
                const SizedBox(height: 20),
                _section('SETTINGS'),
                const SizedBox(height: 4),
                _ToggleRow(
                  icon: Icons.bolt_rounded,
                  label: 'Auto-generate on send',
                  sublabel: 'Synthesize TTS right after sending',
                  value: autoGenerateOnSend,
                  onChanged: onToggleAutoGenerate,
                ),
                _ToggleRow(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Auto-play after generate',
                  sublabel: 'Plays the new line once it finishes',
                  value: autoPlayAfterGenerate,
                  onChanged:
                      autoGenerateOnSend ? onToggleAutoPlay : null,
                ),
                const SizedBox(height: 20),
                _section('GENERATION'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: lines.isEmpty ||
                            generatingAll ||
                            bankAssets.isEmpty
                        ? null
                        : onGenerateAll,
                    icon: generatingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      generatingAll
                          ? 'Generating…'
                          : pending > 0
                              ? 'Generate All ($pending)'
                              : 'Generate All',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: VoicePicker(
              assets: bankAssets,
              activeVoiceId: activeVoiceId,
              lines: lines,
              onPickVoice: onPickVoice,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _statTile(
      {required IconData icon,
      required String label,
      required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55))),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '0:00';
    final total = seconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: Colors.white
                      .withValues(alpha: disabled ? 0.2 : 0.55)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(
                                alpha: disabled ? 0.3 : 0.85))),
                    Text(sublabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(
                                alpha: disabled ? 0.2 : 0.4))),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
