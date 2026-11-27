import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// How the window frame is drawn around the app.
enum WindowChrome {
  /// Transparent title bar: the traffic lights float over the sidebar and
  /// page headers move the window.
  macos,

  /// No native title bar: the app draws the caption buttons in a strip
  /// right of the sidebar, and that strip and page headers move the window.
  windows,

  /// The platform's own frame (Linux header bar), or none (web, phones).
  native,
}

WindowChrome get hostWindowChrome {
  if (kIsWeb) return WindowChrome.native;
  if (Platform.isMacOS) return WindowChrome.macos;
  if (Platform.isWindows) return WindowChrome.windows;
  return WindowChrome.native;
}

/// The chrome in use; tests override it to lay out another platform.
final windowChromeProvider = Provider<WindowChrome>((ref) => hostWindowChrome);

/// Whether empty header space can start a window drag.
final bool windowDragSupported = hostWindowChrome != WindowChrome.native;

/// With the native title bar gone, header rows wrap themselves in this to
/// move the window: buttons inside keep their taps and drags (they win the
/// gesture arena), empty space starts a window drag.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => windowDragSupported
      ? GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => windowManager.startDragging(),
          child: child,
        )
      : child;
}
