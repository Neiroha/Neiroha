import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:neiroha/presentation/widgets/settings/role_skill_settings.dart';

import 'capability_defaults_view.dart';
import 'provider_draft.dart';
import 'provider_list.dart';

/// The AI services page: a root level (the pages beside the navigation)
/// and the provider level (one provider's settings beside the list).
enum ProviderPageView {
  providers,
  defaults,
  roleAi,

  /// The selected provider's settings.
  provider,
}

final providerPageViewProvider = StateProvider<ProviderPageView>(
  (ref) => ProviderPageView.providers,
);

/// Tab the provider editor opens on; null opens the overview.
final providerFocusCapabilityProvider = StateProvider<AiCapability?>(
  (ref) => null,
);

/// On narrow windows only one pane shows: the navigation, or this page.
final providerCompactPageOpenProvider = StateProvider<bool>((ref) => false);

/// Shows provider [id]'s settings, on [cap]'s tab when given.
void openProvider(WidgetRef ref, String id, {AiCapability? cap}) {
  ref.read(selectedProviderIdProvider.notifier).state = id;
  ref.read(providerFocusCapabilityProvider.notifier).state = cap;
  ref.read(providerPageViewProvider.notifier).state = ProviderPageView.provider;
  ref.read(providerCompactPageOpenProvider.notifier).state = true;
}

/// Shows a root page of the AI services page.
void showProviderPage(WidgetRef ref, ProviderPageView view) {
  ref.read(providerPageViewProvider.notifier).state = view;
  ref.read(providerCompactPageOpenProvider.notifier).state = true;
}

/// The root navigation: defaults per capability, the role assignment AI
/// and the providers.
class ProviderNavPane extends ConsumerWidget {
  const ProviderNavPane({super.key, required this.providers});
  final List<db.TtsProvider> providers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(providerPageViewProvider);
    final enabled = providers.where((p) => p.enabled).length;
    return Container(
      color: context.colors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WindowDragArea(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
              child: Text(
                l.navProviders,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _HubTile(
                  icon: Icons.dns_rounded,
                  title: l.provHubConnections,
                  subtitle: l.provHubConnectionsShort(
                    providers.length,
                    enabled,
                  ),
                  selected:
                      view == ProviderPageView.providers ||
                      view == ProviderPageView.provider,
                  onTap: () =>
                      showProviderPage(ref, ProviderPageView.providers),
                ),
                _HubTile(
                  icon: Icons.hub_rounded,
                  title: l.provHubDefaults,
                  subtitle: l.provHubDefaultsShort,
                  selected: view == ProviderPageView.defaults,
                  onTap: () => showProviderPage(ref, ProviderPageView.defaults),
                ),
                // Role analysis needs the desktop task runtime.
                if (!kIsWeb)
                  _HubTile(
                    icon: Icons.psychology_alt_rounded,
                    title: l.settingsRoleAi,
                    subtitle: l.provHubRoleAiShort,
                    selected: view == ProviderPageView.roleAi,
                    onTap: () => showProviderPage(ref, ProviderPageView.roleAi),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Material(
      color: selected
          ? AppTheme.accentColor.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 17, color: AppTheme.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fg.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.fg.withValues(alpha: selected ? 0.6 : 0.25),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 「AI 服务 → 服务商」: every connection; a row opens its settings.
class ProvidersPage extends ConsumerWidget {
  const ProvidersPage({super.key, required this.providers, this.onBack});
  final List<db.TtsProvider> providers;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep rows readable on wide panes: cap and center them.
        final side = ((constraints.maxWidth - HubPageBody.maxWidth) / 2).clamp(
          8.0,
          double.infinity,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              icon: Icons.dns_rounded,
              title: l.provHubConnections,
              subtitle: l.provProvidersHint,
              onBack: onBack,
              actions: [
                FilledButton.tonalIcon(
                  onPressed: () => showAddProviderDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.uiAddProvider),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ProviderList(
                providers: providers,
                selectedId: null,
                showChevron: true,
                padding: EdgeInsets.symmetric(horizontal: side),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 「AI 服务 → 分角色 AI」: the shared profile, model and stage prompts.
class RoleAiView extends StatelessWidget {
  const RoleAiView({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          icon: Icons.psychology_alt_rounded,
          title: l.settingsRoleAi,
          subtitle: l.settingsRoleAiDescription,
          onBack: onBack,
        ),
        const Divider(height: 1),
        const Expanded(child: HubPageBody(children: [RoleSkillSettingsCard()])),
      ],
    );
  }
}
