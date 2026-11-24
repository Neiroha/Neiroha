import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
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
      return _TwoPane(
        width: _listWidthProvider,
        defaultWidth: 320,
        left: _ProviderLevelList(
          providers: providers,
          selectedId: selected.id,
          onBack: toProviders,
        ),
        right: editor,
      );
    }
    if (!twoPane) {
      return pageOpen
          ? page(onBack: toRoot)
          : ProviderNavPane(providers: providers);
    }
    return _TwoPane(
      width: _navWidthProvider,
      defaultWidth: 248,
      left: ProviderNavPane(providers: providers),
      right: page(),
    );
  }
}

/// Side pane widths, kept while the app runs; null is the default.
final _navWidthProvider = StateProvider<double?>((ref) => null);
final _listWidthProvider = StateProvider<double?>((ref) => null);

const double _minSideWidth = 200;

/// A side pane beside the content, split by a divider that drags to
/// resize and double-clicks back to [defaultWidth].
class _TwoPane extends ConsumerWidget {
  const _TwoPane({
    required this.width,
    required this.defaultWidth,
    required this.left,
    required this.right,
  });
  final StateProvider<double?> width;
  final double defaultWidth;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final max = (constraints.maxWidth / 2).clamp(
        _minSideWidth,
        double.infinity,
      );
      final current = (ref.watch(width) ?? defaultWidth).clamp(
        _minSideWidth,
        max,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: current, child: left),
          _PaneDivider(
            onDrag: (dx) => ref.read(width.notifier).state =
                ((ref.read(width) ?? defaultWidth) + dx).clamp(
                  _minSideWidth,
                  max,
                ),
            onReset: () => ref.read(width.notifier).state = null,
          ),
          Expanded(child: right),
        ],
      );
    },
  );
}

class _PaneDivider extends StatefulWidget {
  const _PaneDivider({required this.onDrag, required this.onReset});
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  State<_PaneDivider> createState() => _PaneDividerState();
}

class _PaneDividerState extends State<_PaneDivider> {
  bool _hot = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hot || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: 9,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 1,
              color: active
                  ? AppTheme.accentColor.withValues(alpha: 0.7)
                  : Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

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
