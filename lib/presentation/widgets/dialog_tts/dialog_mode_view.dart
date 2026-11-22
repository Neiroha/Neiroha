import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/data/services/conversation/conversation_engine.dart';
import 'package:neiroha/data/services/conversation/conversation_factory.dart';
import 'package:neiroha/domain/platform/platform_capabilities.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/ai_capability_providers.dart';

import 'live_conversation_panel.dart';

/// Switches the dialog editor between the script (type lines, generate
/// audio) and the live modes where the character talks back.
class DialogModeView extends ConsumerStatefulWidget {
  const DialogModeView({
    super.key,
    required this.bankAssets,
    required this.voiceId,
    required this.script,
  });

  final List<db.VoiceAsset> bankAssets;
  final String? voiceId;
  final Widget script;

  @override
  ConsumerState<DialogModeView> createState() => _DialogModeViewState();
}

class _DialogModeViewState extends ConsumerState<DialogModeView> {
  DialogMode _mode = DialogMode.script;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final router = ref.watch(aiCapabilityRouterProvider).value;
    final available = router == null || PlatformCapabilities.current().isWeb
        ? const {DialogMode.script}
        : ConversationFactory(router).availableModes();
    final mode = available.contains(_mode) ? _mode : DialogMode.script;
    String label(DialogMode m) => switch (m) {
      DialogMode.script => l.liveModeScript,
      DialogMode.realtime => l.liveModeRealtime,
      DialogMode.companion => l.liveModeCompanion,
    };
    String hint(DialogMode m) => available.contains(m)
        ? switch (m) {
            DialogMode.script => l.liveModeScriptHint,
            DialogMode.realtime => l.liveModeRealtimeHint,
            DialogMode.companion => l.liveModeCompanionHint,
          }
        : m == DialogMode.realtime
        ? l.liveNeedsRealtime
        : l.liveNeedsCompanion;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SegmentedButton<DialogMode>(
            showSelectedIcon: false,
            segments: [
              for (final m in DialogMode.values)
                ButtonSegment(
                  value: m,
                  enabled: available.contains(m),
                  tooltip: hint(m),
                  label: Text(label(m)),
                  icon: Icon(switch (m) {
                    DialogMode.script => Icons.notes_rounded,
                    DialogMode.realtime => Icons.graphic_eq_rounded,
                    DialogMode.companion => Icons.record_voice_over_rounded,
                  }, size: 18),
                ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Expanded(
          child: mode == DialogMode.script
              ? widget.script
              : LiveConversationPanel(
                  key: ValueKey(mode),
                  mode: mode,
                  bankAssets: widget.bankAssets,
                  initialVoiceId: widget.voiceId,
                ),
        ),
      ],
    );
  }
}
