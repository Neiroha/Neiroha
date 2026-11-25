import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/layout/side_panes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/presentation/screens/voice_character_screen.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/loudness_fields.dart';
import 'package:neiroha/presentation/widgets/quick_tts_panel.dart';
import 'package:neiroha/presentation/widgets/resizable_split_pane.dart';
import 'package:neiroha/presentation/widgets/voice_bank/voice_bank_widgets.dart';
import 'package:neiroha/providers/app_providers.dart';
import 'package:neiroha/providers/playback_provider.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

part '../widgets/voice_bank/bank_actions.dart';
part '../widgets/voice_bank/bank_columns.dart';
part '../widgets/voice_bank/bank_detail.dart';
part '../widgets/voice_bank/bank_switcher.dart';

/// Merged Voice Bank + Voice Characters screen.
///
/// Wide windows show three columns:
///   • Left   — the bank switcher (with the bank's actions) over its cast
///   • Middle — Quick test for the selected character
///   • Right  — Character inspector (inline editor)
/// The side columns drag to resize. Narrower windows put the quick test
/// over the inspector beside the cast, one pane at a time when compact.
///
/// "Import from other bank" just adds an existing [db.VoiceAsset] as a
/// [db.VoiceBankMember] of the current bank — characters are shared across
/// banks, never deep-copied.
/// From this width the quick test gets its own column.
const double _threePaneMinWidth = 1080;

/// Side column widths, kept while the app runs; null is the default.
final _castWidthProvider = StateProvider<double?>((ref) => null);
final _inspectorWidthProvider = StateProvider<double?>((ref) => null);

class VoiceBankScreen extends ConsumerStatefulWidget {
  const VoiceBankScreen({super.key});

  @override
  ConsumerState<VoiceBankScreen> createState() => _VoiceBankScreenState();
}

class _VoiceBankScreenState extends ConsumerState<VoiceBankScreen> {
  String? _selectedBankId;
  String _characterFilter = '';
  late final TextEditingController _searchCtrl;
  final _characterSplitKey = GlobalKey<ResizableSplitPaneState>();

  // Cached notifier references captured while the widget is still mounted.
  // Reading via `ref` inside [dispose] throws — the ConsumerStatefulElement
  // has already been disposed by then. Notifiers themselves live in the
  // enclosing ProviderScope, so calling them after widget dispose is safe.
  late final StateController<String?> _selectedCharacterCtl;
  late final PlaybackNotifier _playbackNotifier;

  /// [setState] for the part-file extensions, which may not call it.
  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _selectedCharacterCtl = ref.read(selectedCharacterIdProvider.notifier);
    _playbackNotifier = ref.read(playbackNotifierProvider.notifier);
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() {
      setState(() => _characterFilter = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    // Capture locally — fields become unreadable after super.dispose().
    final selectedCtl = _selectedCharacterCtl;
    final playback = _playbackNotifier;
    // Defer provider mutations: writing to a StateProvider while the widget
    // tree is being torn down raises "Tried to modify a provider while the
    // widget tree was building". Future(...) schedules it on the next event-
    // loop tick, after finalizeTree completes.
    // The scope may be gone too when the whole app tears down.
    Future(() {
      if (!selectedCtl.mounted) return;
      selectedCtl.state = null;
      unawaited(playback.stopIfSourceTag(voiceBankQuickTestPlaybackSource));
    });
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Call while the widget is still mounted (e.g. from a button handler).
  /// Not safe from [dispose] — that path uses a deferred variant inline.
  void _clearVoiceBankInspectorState() {
    _selectedCharacterCtl.state = null;
    unawaited(
      _playbackNotifier.stopIfSourceTag(voiceBankQuickTestPlaybackSource),
    );
  }

  @override
  Widget build(BuildContext context) {
    _keepBankSelected(ref.watch(voiceBanksStreamProvider).value);
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide: the cast, the quick test in the middle (the pane used
              // most), and the character's settings on the right.
              if (constraints.maxWidth >= _threePaneMinWidth) {
                return SidePaneRow(
                  left: _buildCharacterColumn(),
                  leftWidth: _castWidthProvider,
                  leftDefault: 280,
                  center: _buildQuickTestColumn(),
                  right: _buildInspectorColumn(),
                  rightWidth: _inspectorWidthProvider,
                  rightDefault: 420,
                  minSide: 240,
                  minCenter: 360,
                );
              }
              return ResizableSplitPane(
                key: _characterSplitKey,
                initialLeftFraction: 0.4,
                compactRightIcon: Icons.tune_rounded,
                compactRightLabel: AppLocalizations.of(context).uiDetails,
                left: _buildCharacterColumn(),
                rightBuilder: (_) => _buildStackedDetail(),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Keeps a bank chosen: the active one first, so the cast shows at once
  /// and after the chosen bank is deleted.
  void _keepBankSelected(List<db.VoiceBank>? banks) {
    if (banks == null || banks.isEmpty) return;
    if (banks.any((b) => b.id == _selectedBankId)) return;
    final pick = (banks.where((b) => b.isActive).firstOrNull ?? banks.first).id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedBankId == pick) return;
      _clearVoiceBankInspectorState();
      setState(() => _selectedBankId = pick);
    });
  }

  // ───────────────── Header ─────────────────

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => PageHeader(
        icon: Icons.record_voice_over_rounded,
        title: l10n.navVoiceBank,
        subtitle: constraints.maxWidth < 600
            ? null
            : l10n.uiBanksCharactersAndInspector,
        actions: [
          if (constraints.maxWidth < 1100)
            IconButton.filledTonal(
              tooltip: l10n.uiNewBank,
              onPressed: _createBank,
              icon: const Icon(Icons.add_rounded),
            )
          else
            FilledButton.icon(
              onPressed: _createBank,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.uiNewBank),
            ),
        ],
      ),
    );
  }

  String _databaseErrorMessage(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }
}
