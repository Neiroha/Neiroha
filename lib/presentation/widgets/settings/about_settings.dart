import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/app_version.dart';
import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/data/services/update/update_checker.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/widgets/external_link.dart';
import 'package:neiroha/presentation/widgets/update_dialog.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'settings_shared.dart';

class AboutSettingsCard extends StatelessWidget {
  const AboutSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'Neiroha',
              subtitle: l10n.aboutSubtitle(appVersion),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const UpdateSettingsCard(),
      ],
    );
  }
}

/// Check for a newer release now, and whether to check at startup.
class UpdateSettingsCard extends ConsumerStatefulWidget {
  const UpdateSettingsCard({super.key});

  @override
  ConsumerState<UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

enum _Check { idle, checking, upToDate, available, failed }

class _UpdateSettingsCardState extends ConsumerState<UpdateSettingsCard> {
  bool _auto = true;
  bool _loaded = false;
  _Check _check = _Check.idle;
  AppRelease? _release;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final stored = await ref
          .read(databaseProvider)
          .getSetting(UpdateSettings.autoCheckKey);
      if (!mounted) return;
      setState(() {
        _auto = UpdateSettings.parseAutoCheck(stored);
        _loaded = true;
      });
    });
  }

  Future<void> _setAuto(bool value) async {
    setState(() => _auto = value);
    await ref
        .read(databaseProvider)
        .setSetting(UpdateSettings.autoCheckKey, '$value');
  }

  Future<void> _checkNow() async {
    setState(() => _check = _Check.checking);
    try {
      final release = await ref.read(updateCheckerProvider).newerRelease();
      if (!mounted) return;
      setState(() {
        _release = release;
        _check = release == null ? _Check.upToDate : _Check.available;
      });
      if (release != null) await showUpdateDialog(context, ref, release);
    } catch (_) {
      if (mounted) setState(() => _check = _Check.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final release = _release;
    final status = switch (_check) {
      _Check.idle => l10n.updateCurrent(appVersion),
      _Check.checking => l10n.updateChecking,
      _Check.upToDate => l10n.updateUpToDate(appVersion),
      _Check.available => l10n.updateAvailableTitle(release!.version),
      _Check.failed => l10n.updateCheckFailed,
    };
    final checker = ref.read(updateCheckerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            SettingsRow(
              icon: Icons.system_update_alt_rounded,
              title: l10n.updateTitle,
              subtitle: status,
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_check == _Check.available)
                    FilledButton.icon(
                      onPressed: () => openExternalLink(context, release!.url),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.updateDownload),
                    ),
                  OutlinedButton.icon(
                    onPressed: _check == _Check.checking ? null : _checkNow,
                    icon: _check == _Check.checking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.updateCheckNow),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            SettingsRow(
              icon: Icons.notifications_active_rounded,
              title: l10n.updateAutoTitle,
              subtitle: l10n.updateAutoSubtitle,
              trailing: Switch(
                value: _auto,
                onChanged: _loaded ? _setAuto : null,
              ),
            ),
            const Divider(height: 16),
            SettingsRow(
              icon: Icons.open_in_new_rounded,
              title: l10n.updateReleasesPage,
              subtitle: checker.releasesPage,
              trailing: IconButton(
                tooltip: l10n.updateReleasesPage,
                icon: Icon(
                  Icons.arrow_outward_rounded,
                  color: context.fg.withValues(alpha: 0.6),
                ),
                onPressed: () =>
                    openExternalLink(context, checker.releasesPage),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
