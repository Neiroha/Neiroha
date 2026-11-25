import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neiroha/app_version.dart';
import 'package:neiroha/data/database/app_database.dart'
    show AppDatabaseStorageQueries;
import 'package:neiroha/data/services/update/update_checker.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/providers/app_providers.dart';

import 'external_link.dart';

final updateCheckerProvider = Provider<UpdateChecker>((_) => UpdateChecker());

/// At startup, when automatic checks are on: looks for a newer release and
/// offers it, unless the user skipped that version. Failures stay silent.
Future<void> checkForUpdateAtStartup(
  BuildContext context,
  WidgetRef ref,
) async {
  final database = ref.read(databaseProvider);
  try {
    final auto = UpdateSettings.parseAutoCheck(
      await database.getSetting(UpdateSettings.autoCheckKey),
    );
    if (!auto) return;
    final release = await ref.read(updateCheckerProvider).newerRelease();
    if (release == null) return;
    final skipped = await database.getSetting(UpdateSettings.skippedKey);
    if (skipped == release.version || !context.mounted) return;
    await showUpdateDialog(context, ref, release);
  } catch (_) {
    // Offline or rate-limited: try again next launch.
  }
}

/// Offers [release]: download, later, or skip this version.
Future<void> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) {
  final l10n = AppLocalizations.of(context);
  final fg = context.fg;
  final date = release.publishedAt?.toLocal();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.system_update_alt_rounded,
        color: AppTheme.accentColor,
      ),
      title: Text(l10n.updateAvailableTitle(release.version)),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.updateAvailableBody(appVersion, release.version),
              style: TextStyle(color: fg.withValues(alpha: 0.7)),
            ),
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.updatePublished(
                  MaterialLocalizations.of(ctx).formatMediumDate(date),
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: fg.withValues(alpha: 0.5),
                ),
              ),
            ],
            if (release.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: ctx.colors.panel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    release.notes,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ref
                .read(databaseProvider)
                .setSetting(UpdateSettings.skippedKey, release.version);
          },
          child: Text(l10n.updateSkipVersion),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.updateLater),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            openExternalLink(context, release.url);
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(l10n.updateDownload),
        ),
      ],
    ),
  );
}
