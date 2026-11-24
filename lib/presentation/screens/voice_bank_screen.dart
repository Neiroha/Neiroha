import 'package:neiroha/data/ai/registry/tts_adapter_factory.dart';
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
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

/// Merged Voice Bank + Voice Characters screen.
///
/// Three columns:
///   • Left   — Bank list (select / create / rename / duplicate / activate)
///   • Middle — Characters in the selected bank (search, new, import-from-other-bank)
///   • Right  — Character inspector (inline editor, from voice_character_screen.dart)
///
/// "Import from other bank" just adds an existing [db.VoiceAsset] as a
/// [db.VoiceBankMember] of the current bank — characters are shared across
/// banks, never deep-copied.
class VoiceBankScreen extends ConsumerStatefulWidget {
  const VoiceBankScreen({super.key});

  @override
  ConsumerState<VoiceBankScreen> createState() => _VoiceBankScreenState();
}

class _VoiceBankScreenState extends ConsumerState<VoiceBankScreen> {
  String? _selectedBankId;
  String _characterFilter = '';
  late final TextEditingController _searchCtrl;
  final _bankSplitKey = GlobalKey<ResizableSplitPaneState>();
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
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(
          child: ResizableSplitPane(
            key: _bankSplitKey,
            initialLeftFraction: 0.22,
            compactRightIcon: Icons.people_alt_rounded,
            compactRightLabel: AppLocalizations.of(context).uiCharacters,
            left: _buildBankList(),
            rightBuilder: (_) => ResizableSplitPane(
              key: _characterSplitKey,
              initialLeftFraction: 0.45,
              compactRightIcon: Icons.tune_rounded,
              compactRightLabel: AppLocalizations.of(context).uiDetails,
              left: _buildCharacterColumn(),
              rightBuilder: (_) => _buildInspectorColumn(),
            ),
          ),
        ),
      ],
    );
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

  // ───────────────── Left column: Bank list ─────────────────

  Widget _buildBankList() {
    final banksAsync = ref.watch(voiceBanksStreamProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            AppLocalizations.of(context).uiBANKS,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: banksAsync.when(
            loading: () => Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(AppLocalizations.of(context).uiError2(e))),
            data: (banks) {
              if (banks.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalizations.of(context).uiNoBanksYet,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: banks.length,
                itemBuilder: (ctx, i) {
                  final bank = banks[i];
                  final selected = _selectedBankId == bank.id;
                  return VoiceBankTile(
                    bank: bank,
                    isSelected: selected,
                    onTap: () {
                      _clearVoiceBankInspectorState();
                      setState(() => _selectedBankId = bank.id);
                      _showBankCharactersPane();
                    },
                    onDelete: () async {
                      try {
                        await ref.read(databaseProvider).deleteBank(bank.id);
                        if (_selectedBankId == bank.id) {
                          _clearVoiceBankInspectorState();
                          setState(() => _selectedBankId = null);
                          _bankSplitKey.currentState?.showLeftPane(
                            onlyWhenCompact: true,
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_databaseErrorMessage(e))),
                        );
                      }
                    },
                    onDuplicate: () async {
                      final newBank = await ref
                          .read(databaseProvider)
                          .duplicateBank(bank.id, '${bank.name} (copy)');
                      _clearVoiceBankInspectorState();
                      setState(() => _selectedBankId = newBank.id);
                      _showBankCharactersPane();
                    },
                    onToggleActive: () async {
                      final database = ref.read(databaseProvider);
                      if (bank.isActive) {
                        await database.deactivateAllBanks();
                      } else {
                        await database.setActiveBank(bank.id);
                      }
                    },
                    onRename: () => _renameBank(bank, banks),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _databaseErrorMessage(Object error) {
    if (error is StateError) return error.message;
    return error.toString();
  }
}
