import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neiroha/presentation/widgets/layout/window_drag_area.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'about_settings.dart';
import 'api_settings.dart';
import 'general_settings.dart';
import 'nav_order_settings.dart';
import 'media_settings.dart';
import 'storage_settings.dart';
import 'task_settings.dart';

const double _settingsContentMaxWidth = 920;

class SettingsSectionRail extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  const SettingsSectionRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: context.colors.sidebar,
      child: Column(
        children: [
          WindowDragArea(
            child: Container(
              height: 52,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.settingsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final section in SettingsSection.values)
                  _SettingsSectionTile(
                    section: section,
                    selected: section == selected,
                    label: section.localizedLabel(l10n),
                    onTap: () => onSelected(section),
                  ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                const _AiServicesLink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTile extends StatefulWidget {
  final SettingsSection section;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _SettingsSectionTile({
    required this.section,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  State<_SettingsSectionTile> createState() => _SettingsSectionTileState();
}

class _SettingsSectionTileState extends State<_SettingsSectionTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected
        ? context.fg.withValues(alpha: 0.94)
        : context.fg.withValues(alpha: _hovering ? 0.82 : 0.68);
    final iconColor = selected
        ? AppTheme.accentColor
        : context.fg.withValues(alpha: _hovering ? 0.76 : 0.58);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 46,
          color: _hovering
              ? context.fg.withValues(alpha: 0.025)
              : Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                width: 3,
                height: selected ? 30 : 0,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accentColor : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Icon(widget.section.icon, size: 22, color: iconColor),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsCompactPicker extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  const SettingsCompactPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: context.colors.panel,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final section in SettingsSection.values) ...[
                  ChoiceChip(
                    selected: selected == section,
                    avatar: Icon(section.icon, size: 16),
                    label: Text(section.localizedLabel(l10n)),
                    onSelected: (_) => onSelected(section),
                  ),
                  const SizedBox(width: 8),
                ],
                const _AiServicesLink(compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSectionContent extends ConsumerWidget {
  final SettingsSection section;

  const SettingsSectionContent({super.key, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final children = switch (section) {
      SettingsSection.general => const <Widget>[
        LanguageSettingsCard(),
        SizedBox(height: 8),
        FontSettingsCard(),
        SizedBox(height: 8),
        StartupSettingsCard(),
        SizedBox(height: 8),
        NavOrderSettingsCard(),
        SizedBox(height: 8),
        TaskBehaviorSettingsCard(),
        SizedBox(height: 8),
        HealthCheckTimeoutSettingsCard(),
      ],
      SettingsSection.tasks => const <Widget>[TaskMonitorSettingsCard()],
      SettingsSection.storage when kIsWeb => <Widget>[
        Text(l10n.webStorageDescription),
      ],
      SettingsSection.api || SettingsSection.media when kIsWeb => <Widget>[
        Text(l10n.webFeatureUnavailable),
      ],
      SettingsSection.api => const <Widget>[ApiServerSettingsCard()],
      SettingsSection.storage => <Widget>[
        StorageSettingsCard(startup: ref.watch(storageStartupProvider)),
      ],
      SettingsSection.media => const <Widget>[
        FfmpegSettingsCard(),
        SizedBox(height: 8),
        ExportPrefsSettingsCard(),
      ],
      SettingsSection.about => const <Widget>[AboutSettingsCard()],
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _settingsContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            _SettingsPageHeader(section: section),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsPageHeader extends StatelessWidget {
  final SettingsSection section;

  const _SettingsPageHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WindowDragArea(
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: section.localizedLabel(l10n),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            children: [
              const TextSpan(text: '   '),
              TextSpan(
                text: section.localizedDescription(l10n),
                style: TextStyle(
                  color: context.fg.withValues(alpha: 0.45),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Models and providers live on the AI services page; settings point there
/// instead of keeping a second copy.
class _AiServicesLink extends ConsumerWidget {
  const _AiServicesLink({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open() =>
        ref.read(selectedTabProvider.notifier).state = NavTab.providers;
    if (compact) {
      return ActionChip(
        avatar: const Icon(Icons.dns_rounded, size: 16),
        label: Text(l10n.navProviders),
        onPressed: open,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.dns_rounded, size: 20),
        title: Text(l10n.navProviders),
        subtitle: Text(
          l10n.settingsAiServicesHint,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_outward_rounded, size: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: open,
      ),
    );
  }
}
