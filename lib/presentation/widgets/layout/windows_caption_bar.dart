import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The Windows title strip of a frameless window: a drag area (double-click
/// maximizes, right-click opens the system menu) and the three caption
/// buttons drawn with the system's own glyphs.
///
/// Sits right of the sidebar on wide layouts, so the sidebar keeps the full
/// height as on macOS; across the top on compact ones, with [title].
class WindowsCaptionBar extends StatefulWidget {
  const WindowsCaptionBar({super.key, this.title, this.color});

  /// Shown at the left when no sidebar names the app.
  final String? title;
  final Color? color;

  static const height = 32.0;

  @override
  State<WindowsCaptionBar> createState() => _WindowsCaptionBarState();
}

class _WindowsCaptionBarState extends State<WindowsCaptionBar>
    with WindowListener {
  bool _maximized = false;
  bool _focused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      final maximized = await windowManager.isMaximized();
      final focused = await windowManager.isFocused();
      if (mounted) {
        setState(() {
          _maximized = maximized;
          _focused = focused;
        });
      }
    } catch (_) {
      // No window (tests): keep the defaults.
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowFocus() => setState(() => _focused = true);

  @override
  void onWindowBlur() => setState(() => _focused = false);

  Future<void> _toggleMaximize() async =>
      _maximized ? windowManager.unmaximize() : windowManager.maximize();

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    return Container(
      height: WindowsCaptionBar.height,
      color: widget.color ?? Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              onSecondaryTap: windowManager.popUpWindowMenu,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: title == null
                      ? null
                      : Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(
                              alpha: _focused ? 0.6 : 0.35,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          _CaptionButton(
            glyph: _Glyph.minimize,
            focused: _focused,
            onTap: windowManager.minimize,
          ),
          _CaptionButton(
            glyph: _maximized ? _Glyph.restore : _Glyph.maximize,
            focused: _focused,
            onTap: _toggleMaximize,
          ),
          _CaptionButton(
            glyph: _Glyph.close,
            focused: _focused,
            onTap: windowManager.close,
          ),
        ],
      ),
    );
  }
}

/// Segoe Fluent Icons (Windows 11) / Segoe MDL2 Assets (Windows 10) code
/// points of the window chrome glyphs.
enum _Glyph {
  minimize(''),
  maximize(''),
  restore(''),
  close('');

  const _Glyph(this.char);
  final String char;
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.glyph,
    required this.focused,
    required this.onTap,
  });
  final _Glyph glyph;
  final bool focused;
  final VoidCallback onTap;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;
  bool _down = false;

  /// Windows 11's close-button red.
  static const _closeRed = Color(0xFFC42B1C);

  @override
  Widget build(BuildContext context) {
    final close = widget.glyph == _Glyph.close;
    final background = !_hover
        ? Colors.transparent
        : close
        ? _closeRed.withValues(alpha: _down ? 0.85 : 1)
        : Colors.white.withValues(alpha: _down ? 0.05 : 0.08);
    final foreground = close && _hover
        ? Colors.white
        : Colors.white.withValues(alpha: widget.focused ? 0.85 : 0.4);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          setState(() => _down = false);
          widget.onTap();
        },
        child: Container(
          width: 46,
          height: WindowsCaptionBar.height,
          color: background,
          alignment: Alignment.center,
          child: Text(
            widget.glyph.char,
            style: TextStyle(
              fontFamily: 'Segoe Fluent Icons',
              fontFamilyFallback: const ['Segoe MDL2 Assets'],
              fontSize: 10,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
