import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neiroha/data/database/app_database.dart' as db;
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/providers/app_providers.dart';

void warnIfVoiceHealthFailedOnce({
  required BuildContext context,
  required WidgetRef ref,
  required db.VoiceAsset asset,
}) {
  final health = ref.read(voiceHealthStatusProvider).valueOrNull;
  if (health?[asset.id] != false) return;
  final warned = ref.read(warnedUnhealthyVoiceIdsProvider);
  if (warned.contains(asset.id)) return;
  ref.read(warnedUnhealthyVoiceIdsProvider.notifier).state = {
    ...warned,
    asset.id,
  };
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        AppLocalizations.of(context).unhealthyVoiceWarning(asset.name),
      ),
    ),
  );
}
