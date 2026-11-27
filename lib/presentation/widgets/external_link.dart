import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neiroha/l10n/generated/app_localizations.dart';

/// Opens [url] in the default browser on desktop. Where that is not
/// possible (web, mobile, a failure) the link is copied instead and a
/// snackbar says so.
Future<void> openExternalLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copied = AppLocalizations.of(context).linkCopied;
  if (!kIsWeb) {
    try {
      final result = Platform.isMacOS
          ? await Process.run('open', [url])
          : Platform.isWindows
          ? await Process.run('rundll32', ['url.dll,FileProtocolHandler', url])
          : Platform.isLinux
          ? await Process.run('xdg-open', [url])
          : null;
      if (result != null && result.exitCode == 0) return;
    } catch (_) {
      // Fall through to copying the link.
    }
  }
  await Clipboard.setData(ClipboardData(text: url));
  messenger?.showSnackBar(SnackBar(content: Text(copied)));
}
