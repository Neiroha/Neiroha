import 'package:flutter/widgets.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';
import 'package:neiroha/presentation/navigation/app_navigation.dart';

Widget buildWorkspace(
  BuildContext context,
  NavTab tab, {
  required bool active,
  required ValueChanged<Future<bool> Function()?> onPhaseExitGuardChanged,
}) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      AppLocalizations.of(context).webFeatureUnavailable,
      textAlign: TextAlign.center,
    ),
  ),
);
