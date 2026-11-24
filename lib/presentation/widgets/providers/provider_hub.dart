import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:neiroha/domain/ai/ai.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/layout/page_header.dart';
import 'package:neiroha/presentation/widgets/settings/role_skill_settings.dart';

import 'capability_defaults_view.dart';
import 'provider_draft.dart';

/// What the right pane of the AI services page shows.
enum ProviderPageView { defaults, roleAi, provider }

final providerPageViewProvider = StateProvider<ProviderPageView>(
  (ref) => ProviderPageView.defaults,
);

/// Tab the provider editor opens on; null opens the overview.
final providerFocusCapabilityProvider = StateProvider<AiCapability?>(
  (ref) => null,
);

/// Shows provider [id] in the editor, on [cap]'s tab when given.
void openProvider(WidgetRef ref, String id, {AiCapability? cap}) {
  ref.read(selectedProviderIdProvider.notifier).state = id;
  ref.read(providerFocusCapabilityProvider.notifier).state = cap;
  ref.read(providerPageViewProvider.notifier).state = ProviderPageView.provider;
}

/// The pages above the provider list: defaults per capability, and the
/// role assignment AI.
class ProviderHubTiles extends ConsumerWidget {
  const ProviderHubTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(providerPageViewProvider);
    void show(ProviderPageView v) =>
        ref.read(providerPageViewProvider.notifier).state = v;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Column(
        children: [
          _HubTile(
            icon: Icons.hub_rounded,
            title: l.provHubDefaults,
            subtitle: l.provHubDefaultsShort,
            selected: view == ProviderPageView.defaults,
            onTap: () => show(ProviderPageView.defaults),
          ),
          // Role analysis needs the desktop task runtime.
          if (!kIsWeb)
            _HubTile(
              icon: Icons.psychology_alt_rounded,
              title: l.settingsRoleAi,
              subtitle: l.provHubRoleAiShort,
              selected: view == ProviderPageView.roleAi,
              onTap: () => show(ProviderPageView.roleAi),
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
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: selected ? 0.6 : 0.25),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 「AI 服务 → 分角色 AI」: the shared profile, model and stage prompts.
class RoleAiView extends StatelessWidget {
  const RoleAiView({super.key});

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
        ),
        const Divider(height: 1),
        const Expanded(child: HubPageBody(children: [RoleSkillSettingsCard()])),
      ],
    );
  }
}
