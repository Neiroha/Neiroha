import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// macOS draws content under a transparent title bar, so the native drag
/// strip is gone. Header rows wrap themselves in this to move the window:
/// buttons inside keep their taps and drags (they win the gesture arena),
/// empty space starts a window drag.
final bool windowDragSupported = !kIsWeb && Platform.isMacOS;

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
