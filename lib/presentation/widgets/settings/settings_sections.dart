import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/l10n/localized_labels.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'about_settings.dart';
import 'api_settings.dart';
import 'general_settings.dart';
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
      color: const Color(0xFF12121A),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Center(
            child: Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: SettingsSection.values.length,
              itemBuilder: (context, index) {
                final section = SettingsSection.values[index];
                return _SettingsSectionTile(
                  section: section,
                  selected: section == selected,
                  label: section.localizedLabel(l10n),
                  onTap: () => onSelected(section),
                );
              },
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
        ? Colors.white.withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: _hovering ? 0.82 : 0.68);
    final iconColor = selected
        ? AppTheme.accentColor
        : Colors.white.withValues(alpha: _hovering ? 0.76 : 0.58);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 58,
          color: _hovering
              ? Colors.white.withValues(alpha: 0.025)
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
      color: AppTheme.surfaceDim,
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
    final children = switch (section) {
      SettingsSection.general => const <Widget>[
        LanguageSettingsCard(),
        SizedBox(height: 12),
        FontSettingsCard(),
        SizedBox(height: 12),
        StartupSettingsCard(),
        SizedBox(height: 12),
        TaskBehaviorSettingsCard(),
      ],
      SettingsSection.tasks => const <Widget>[TaskMonitorSettingsCard()],
      SettingsSection.api => const <Widget>[ApiServerSettingsCard()],
      SettingsSection.storage => <Widget>[
        StorageSettingsCard(startup: ref.watch(storageStartupProvider)),
      ],
      SettingsSection.media => const <Widget>[
        FfmpegSettingsCard(),
        SizedBox(height: 12),
        ExportPrefsSettingsCard(),
      ],
      SettingsSection.about => const <Widget>[AboutSettingsCard()],
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _settingsContentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          children: [
            _SettingsPageHeader(section: section),
            const SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          section.localizedLabel(l10n),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          section.localizedDescription(l10n),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
