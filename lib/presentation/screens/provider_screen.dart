import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/layout/side_panes.dart';
import 'package:neiroha/presentation/widgets/providers/capability_defaults_view.dart';
import 'package:neiroha/presentation/widgets/providers/provider_draft.dart';
import 'package:neiroha/presentation/widgets/providers/provider_editor.dart';
import 'package:neiroha/presentation/widgets/providers/provider_hub.dart';
import 'package:neiroha/presentation/widgets/providers/provider_list.dart';
import 'package:neiroha/providers/app_providers.dart';

/// Below this width the AI services page shows one pane at a time.
const double _twoPaneMinWidth = 720;

/// The AI services page: everything about models in one place.
///
/// Root:     navigation (default models, role AI, providers) beside the
///           chosen page.
/// Provider: the provider list beside the selected provider's settings;
///           back returns to the providers page.
///
/// Narrow windows show one pane at a time, with back buttons.
class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(ttsProvidersStreamProvider);
    return providersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(AppLocalizations.of(context).uiError2(e))),
      data: (providers) => LayoutBuilder(
        builder: (context, constraints) => _ProviderLayout(
          providers: providers,
          twoPane: constraints.maxWidth >= _twoPaneMinWidth,
        ),
      ),
    );
  }
}

class _ProviderLayout extends ConsumerWidget {
  const _ProviderLayout({required this.providers, required this.twoPane});
  final List<db.TtsProvider> providers;
  final bool twoPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(providerPageViewProvider);
    final selectedId = ref.watch(selectedProviderIdProvider);
    final pageOpen = ref.watch(providerCompactPageOpenProvider);
    final selected = view == ProviderPageView.provider
        ? providers.where((p) => p.id == selectedId).firstOrNull
        : null;

    void toRoot() =>
        ref.read(providerCompactPageOpenProvider.notifier).state = false;
    void toProviders() => ref.read(providerPageViewProvider.notifier).state =
        ProviderPageView.providers;

    Widget page({VoidCallback? onBack}) => switch (view) {
      ProviderPageView.defaults => CapabilityDefaultsView(onBack: onBack),
      ProviderPageView.roleAi => RoleAiView(onBack: onBack),
      _ => ProvidersPage(providers: providers, onBack: onBack),
    };

    if (selected != null) {
      final editor = ProviderEditor(
        key: ValueKey(selected.id),
        provider: selected,
        onBack: twoPane ? null : toProviders,
      );
      if (!twoPane) return editor;
      return SidePaneRow(
        leftWidth: _listWidthProvider,
        leftDefault: 320,
        left: _ProviderLevelList(
          providers: providers,
          selectedId: selected.id,
          onBack: toProviders,
        ),
        center: editor,
      );
    }
    if (!twoPane) {
      return pageOpen
          ? page(onBack: toRoot)
          : ProviderNavPane(providers: providers);
    }
    return SidePaneRow(
      leftWidth: _navWidthProvider,
      leftDefault: 248,
      left: ProviderNavPane(providers: providers),
      center: page(),
    );
  }
}

/// Side pane widths, kept while the app runs; null is the default.
final _navWidthProvider = StateProvider<double?>((ref) => null);
final _listWidthProvider = StateProvider<double?>((ref) => null);

/// The provider list beside a provider's settings, headed by a way back to
/// the AI services navigation.
class _ProviderLevelList extends ConsumerWidget {
  const _ProviderLevelList({
    required this.providers,
    required this.selectedId,
    required this.onBack,
  });
  final List<db.TtsProvider> providers;
  final String selectedId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Container(
      color: AppTheme.surfaceDim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: l.provHubConnections,
            onBack: onBack,
            backTooltip: l.navProviders,
            actions: [
              IconButton(
                onPressed: () => showAddProviderDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                tooltip: l.uiAddProvider,
              ),
            ],
          ),
          Expanded(
            child: ProviderList(providers: providers, selectedId: selectedId),
          ),
        ],
      ),
    );
  }
}
